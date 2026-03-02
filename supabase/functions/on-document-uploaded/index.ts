import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: any
  schema: string
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()
    console.log('Document upload webhook received:', payload.type)

    // Using 'trip_documents' as it directly links to trips
    if (payload.table !== 'trip_documents' || payload.type !== 'INSERT') {
      return new Response('Ignored', { status: 200 })
    }

    const doc = payload.record
    const companyId = doc.company_id
    const tripId = doc.trip_id

    if (!companyId || !tripId) {
      return new Response('Missing company or trip ID', { status: 200 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Fetch trip number
    const { data: trip } = await supabaseAdmin
      .from('driver_trips')
      .select('trip_number')
      .eq('id', tripId)
      .single()

    const tripNumber = trip?.trip_number || 'Unknown'

    // 2. Fetch company admins and dispatchers with FCM tokens
    const { data: staff } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('company_id', companyId)
      .in('role', ['admin', 'dispatcher'])
      .not('fcm_token', 'is', null)

    if (!staff || staff.length === 0) {
      return new Response('No staff to notify', { status: 200 })
    }

    // 3. Send notifications
    const notifications = staff.map((member) =>
      fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        },
        body: JSON.stringify({
          user_id: member.id,
          title: 'New Document Uploaded',
          body: `New ${doc.document_type || 'document'} for Trip #${tripNumber}`,
          data: {
            type: 'document_uploaded',
            tripId: tripId,
            documentId: doc.id,
          },
        }),
      })
    )

    await Promise.all(notifications)

    return new Response(JSON.stringify({ success: true, notifiedCount: staff.length }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing document upload push:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
