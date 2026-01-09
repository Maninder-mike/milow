// Supabase Edge Function: reset-password
// Allows admin to reset a user's password

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ResetRequest {
    user_id: string
    new_password: string
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Missing authorization header')
        }

        // Admin client for user management
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            { auth: { autoRefreshToken: false, persistSession: false } }
        )

        // User client to verify permissions
        const supabaseUser = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        // Verify current user
        const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
        if (userError || !user) {
            throw new Error('Unauthorized')
        }

        // Check admin role
        const { data: profile } = await supabaseUser
            .from('profiles')
            .select('role, company_id')
            .eq('id', user.id)
            .single()

        if (!profile || profile.role !== 'admin') {
            throw new Error('Only admins can reset passwords')
        }

        // Parse request
        const body: ResetRequest = await req.json()
        if (!body.user_id || !body.new_password) {
            throw new Error('user_id and new_password are required')
        }

        // Verify target user is in same company
        const { data: targetProfile } = await supabaseAdmin
            .from('profiles')
            .select('company_id')
            .eq('id', body.user_id)
            .single()

        if (!targetProfile || targetProfile.company_id !== profile.company_id) {
            throw new Error('User not found in your company')
        }

        // Reset password
        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
            body.user_id,
            { password: body.new_password }
        )

        if (updateError) {
            throw updateError
        }

        // Mark that password must be changed
        await supabaseAdmin
            .from('user_credentials')
            .upsert({
                profile_id: body.user_id,
                generated_username: '', // Will be ignored if exists
                must_change_password: true,
                created_by: user.id,
            }, { onConflict: 'profile_id' })

        return new Response(
            JSON.stringify({ success: true, message: 'Password reset successfully' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error'
        return new Response(
            JSON.stringify({ error: message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
