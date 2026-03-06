import { serve } from "https://deno.land/std@0.177.1/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

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
        const url = new URL(req.url)
        const trackingHash = url.searchParams.get('hash')

        if (!trackingHash) {
            return new Response(JSON.stringify({ error: 'Tracking hash is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Initialize Supabase Client with service token to bypass RLS for public read
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Fetch load details
        const { data: load, error } = await supabaseClient
            .from('loads')
            .select('id, pickup_city, pickup_state, pickup_lat, pickup_lng, delivery_city, delivery_state, current_lat, current_lng, status, updated_at, trip_number, company_id')
            .eq('tracking_hash', trackingHash)
            .single()

        if (error || !load) {
            console.log('Error fetching load:', error)
            return new Response(JSON.stringify({ error: 'Load not found' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Fetch company info (Optional but nice for branding on tracking portal)
        const { data: company } = await supabaseClient
            .from('companies')
            .select('name, logo_url')
            .eq('id', load.company_id)
            .single()

        // Return sanitized tracking data
        const trackingData = {
            id: load.id,
            trip_number: load.trip_number,
            pickup_location: `${load.pickup_city}, ${load.pickup_state}`,
            delivery_location: `${load.delivery_city}, ${load.delivery_state}`,
            status: load.status,
            last_updated: load.updated_at,
            current_location: {
                lat: load.current_lat || load.pickup_lat,
                lng: load.current_lng || load.pickup_lng,
            },
            company: company ? { name: company.name, logo: company.logo_url } : null
        }

        return new Response(JSON.stringify(trackingData), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    } catch (err) {
        console.error(err)
        return new Response(JSON.stringify({ error: 'Internal Server Error' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
})
