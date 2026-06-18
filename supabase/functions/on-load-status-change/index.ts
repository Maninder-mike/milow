import { serve } from 'std/http/server'
import { createClient } from 'supabase'

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
    console.log('Load status webhook received:', payload.type)

    if (payload.table !== 'loads' || payload.type !== 'UPDATE') {
      return new Response('Ignored', { status: 200 })
    }

    const oldStatus = payload.old_record?.status
    const newStatus = payload.record?.status
    const driverId = payload.record?.assigned_driver_id

    if (oldStatus === newStatus || !driverId) {
      console.log('Status unchanged or no driver assigned. Skipping.')
      return new Response('No action needed', { status: 200 })
    }

    console.log(`Load ${payload.record.id} status changed: ${oldStatus} -> ${newStatus}`)

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
          user_id: driverId,
          title: `Load Update: ${payload.record.load_reference || payload.record.id}`,
          body: `Status changed to ${newStatus}`,
          data: {
            type: 'load_status_changed',
            loadId: payload.record.id,
            newStatus: newStatus,
          },
        }),
      }
    )

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing load status push:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
