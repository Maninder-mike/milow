// Supabase Edge Function: on-load-status-change
// Triggered by Database Webhook when a Load is UPDATED
// Checks if 'status' changed and sends notification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface WebhookPayload {
    type: 'INSERT' | 'UPDATE' | 'DELETE'
    table: string
    record: any
    schema: string
    old_record: any
}

serve(async (req) => {
    try {
        const payload: WebhookPayload = await req.json()
        console.log('Webhook received:', payload.type)

        // strict check for UPDATE on 'loads' table
        if (payload.table !== 'loads') {
            return new Response('Ignored: Not loads table', { status: 200 })
        }

        if (payload.type !== 'UPDATE') {
            return new Response('Ignored: Not an UPDATE', { status: 200 })
        }

        const oldStatus = payload.old_record?.status
        const newStatus = payload.record?.status

        if (oldStatus === newStatus) {
            console.log(`Status unchanged (${newStatus}). Skipping notification.`)
            return new Response('Status unchanged', { status: 200 })
        }

        console.log(`Load ${payload.record.id} status changed: ${oldStatus} -> ${newStatus}`)

        // Initialize Supabase Client (Service Role)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // TODO: Fetch necessary details (Broker email, Customer contacts)
        // const { data: load } = await supabaseAdmin.from('loads').select('*, customers(*)').eq('id', payload.record.id).single();

        // TODO: Integrate with Email Provider (Resend, SendGrid, AWS SES)
        // await sendEmail({ to: ..., subject: `Load Update: ${payload.record.load_reference}`, body: ... });

        return new Response(
            JSON.stringify({
                message: `Notification processed for Load ${payload.record.id}`,
                change: `${oldStatus} -> ${newStatus}`
            }),
            { headers: { 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error) {
        console.error('Error processing webhook:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
