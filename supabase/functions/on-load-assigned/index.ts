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
    console.log('Assignment webhook received:', payload.type)

    if (payload.table !== 'loads' || payload.type !== 'UPDATE') {
      return new Response('Ignored', { status: 200 })
    }

    const oldDriverId = payload.old_record?.assigned_driver_id
    const newDriverId = payload.record?.assigned_driver_id

    // Check if a driver was just assigned (was null, now has value)
    if (oldDriverId || !newDriverId) {
      console.log('No new assignment detected. Skipping.')
      return new Response('No action needed', { status: 200 })
    }

    console.log(`Load ${payload.record.id} assigned to driver ${newDriverId}`)

    // Call send-push-notification
    await fetch(
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push-notification`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        },
        body: JSON.stringify({
          user_id: newDriverId,
          title: 'New Load Assigned',
          body: `Load #${payload.record.load_reference || payload.record.id} has been assigned to you.`,
          data: {
            type: 'load_assigned',
            loadId: payload.record.id,
            loadReference: payload.record.load_reference || '',
          },
        }),
      }
    )

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing assignment push:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
