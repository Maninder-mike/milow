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
    console.log('Document review webhook received:', payload.type)

    if (payload.table !== 'trip_documents' || payload.type !== 'UPDATE') {
      return new Response('Ignored', { status: 200 })
    }

    const oldStatus = payload.old_record?.status
    const newStatus = payload.record?.status
    const driverId = payload.record?.user_id

    // Only notify if status changed from pending
    if (oldStatus === newStatus || oldStatus !== 'pending' || !driverId) {
      console.log('Status unchanged or not a transition from pending. Skipping.')
      return new Response('No action needed', { status: 200 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch trip number
    const { data: trip } = await supabaseAdmin
      .from('driver_trips')
      .select('trip_number')
      .eq('id', payload.record.trip_id)
      .single()

    const tripNumber = trip?.trip_number || 'Unknown'
    const docType = payload.record.document_type || 'document'

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
          title: `Document ${newStatus.toUpperCase()}`,
          body: `Your ${docType} for Trip #${tripNumber} has been ${newStatus}.`,
          data: {
            type: 'document_reviewed',
            tripId: payload.record.trip_id,
            status: newStatus,
          },
        }),
      }
    )

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing document review push:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
