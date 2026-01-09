// Supabase Edge Function: invite-user
// Creates a new user with email/password and assigns role

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface InviteRequest {
    email: string
    password: string
    full_name?: string
    role_id?: string
    username?: string
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get authorization header
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Missing authorization header')
        }

        // Create Supabase client with service role for admin operations
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            {
                auth: {
                    autoRefreshToken: false,
                    persistSession: false
                }
            }
        )

        // Create client with user's token to verify permissions
        const supabaseUser = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            {
                global: {
                    headers: { Authorization: authHeader }
                }
            }
        )

        // Get current user
        const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
        if (userError || !user) {
            throw new Error('Unauthorized')
        }

        // Verify user is admin and get company info
        const { data: profile, error: profileError } = await supabaseUser
            .from('profiles')
            .select('role, company_id, companies(name)')
            .eq('id', user.id)
            .single()

        if (profileError || !profile) {
            throw new Error('Profile not found')
        }

        if (profile.role !== 'admin') {
            throw new Error('Only admins can invite users')
        }

        // Parse request body
        const body: InviteRequest = await req.json()

        if (!body.email || !body.password) {
            throw new Error('Email and password are required')
        }

        // Fetch role name from roles table
        let roleName = 'pending';
        if (body.role_id) {
            const { data: roleData, error: roleError } = await supabaseAdmin
                .from('roles')
                .select('name')
                .eq('id', body.role_id)
                .single()

            if (!roleError && roleData) {
                roleName = roleData.name
            }
        }

        // Use Supabase's invite flow - sends email automatically
        const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
            body.email,
            {
                data: {
                    full_name: body.full_name,
                    temp_password: body.password, // Store for reference in email template
                    company_name: profile.companies?.name || 'Milow',
                },
                redirectTo: `${Deno.env.get('SUPABASE_URL')?.replace('.supabase.co', '')}/auth/callback`,
            }
        )

        if (inviteError) {
            // If invite fails (user exists), try creating directly
            const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
                email: body.email,
                password: body.password,
                email_confirm: true,
                user_metadata: {
                    full_name: body.full_name,
                }
            })

            if (createError) {
                throw createError
            }

            // Update profile for directly created user
            await supabaseAdmin
                .from('profiles')
                .update({
                    company_id: profile.company_id,
                    role_id: body.role_id,
                    full_name: body.full_name,
                    role: roleName,
                    is_verified: true,
                })
                .eq('id', newUser.user.id)

            // Store credentials
            if (body.username) {
                await supabaseAdmin
                    .from('user_credentials')
                    .insert({
                        profile_id: newUser.user.id,
                        generated_username: body.username,
                        must_change_password: true,
                        created_by: user.id,
                    })
            }

            return new Response(
                JSON.stringify({
                    success: true,
                    user_id: newUser.user.id,
                    email: newUser.user.email,
                    invite_sent: false,
                    message: 'User created. Share password manually.',
                }),
                {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    status: 200,
                }
            )
        }

        // Update profile for invited user
        await supabaseAdmin
            .from('profiles')
            .update({
                company_id: profile.company_id,
                role_id: body.role_id,
                full_name: body.full_name,
                role: roleName,
                is_verified: true,
            })
            .eq('id', inviteData.user.id)

        // Store credentials
        if (body.username) {
            await supabaseAdmin
                .from('user_credentials')
                .insert({
                    profile_id: inviteData.user.id,
                    generated_username: body.username,
                    must_change_password: true,
                    created_by: user.id,
                })
        }

        return new Response(
            JSON.stringify({
                success: true,
                user_id: inviteData.user.id,
                email: inviteData.user.email,
                invite_sent: true,
                message: 'Invitation email sent via Supabase.',
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error'
        console.error('Error:', message)
        return new Response(
            JSON.stringify({ error: message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
