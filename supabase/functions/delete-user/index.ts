import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Create a Supabase client with the Auth context of the user that called the function.
        // This will be used to verify the caller's identity.
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        )

        // Create a Supabase client with the SERVICE_ROLE_KEY to perform admin actions.
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Get the user from the authorization header
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

        if (userError || !user) {
            throw new Error('Unauthorized')
        }

        // Verify the caller is an admin
        const { data: profile, error: profileError } = await supabaseAdmin
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single()

        if (profileError || !profile) {
            throw new Error('Profile not found')
        }

        if (profile.role !== 'admin' && profile.role !== 'super_admin') {
            throw new Error('Only admins can delete users')
        }

        // Parse request body
        const { user_id } = await req.json()

        if (!user_id) {
            throw new Error('User ID is required')
        }

        // 1. Delete from auth.users (This should cascade to public.profiles if configured, 
        //    but we'll delete profile manually first to be safe and ensure clean cleanup)

        // Delete profile (public schema)
        const { error: deleteProfileError } = await supabaseAdmin
            .from('profiles')
            .delete()
            .eq('id', user_id)

        if (deleteProfileError) {
            console.error('Error deleting profile (continuing to auth delete):', deleteProfileError)
        }

        // Delete auth user
        const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(user_id)

        if (deleteUserError) {
            throw deleteUserError
        }

        return new Response(
            JSON.stringify({
                success: true,
                message: 'User deleted successfully',
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
