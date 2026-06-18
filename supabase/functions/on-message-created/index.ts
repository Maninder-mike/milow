import { serve } from 'std/http/server'
import { createClient } from 'supabase'

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: any
  schema: string
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()
    console.log('Message webhook received:', payload.type)

    if (payload.table !== 'messages' || payload.type !== 'INSERT') {
      return new Response('Ignored', { status: 200 })
    }

    const message = payload.record
    const senderId = message.sender_id
    const receiverId = message.receiver_id
    const loadId = message.load_id

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let targetUserId = receiverId

    // If it's a load-scoped message without a specific receiver, it's for the driver or dispatcher
    if (!targetUserId && loadId) {
      const { data: load } = await supabaseAdmin
        .from('loads')
        .select('assigned_driver_id')
        .eq('id', loadId)
        .single()

      if (load?.assigned_driver_id && load.assigned_driver_id !== senderId) {
        targetUserId = load.assigned_driver_id
      }
    }

    if (!targetUserId) {
      return new Response('No target user for notification', { status: 200 })
    }

    // Get sender name for the notification
    const { data: sender } = await supabaseAdmin
      .from('profiles')
      .select('full_name')
      .eq('id', senderId)
      .single()

    const senderName = sender?.full_name || 'Dispatcher'

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
          user_id: targetUserId,
          title: `New Message from ${senderName}`,
          body: message.content || 'Sent an attachment',
          data: {
            type: 'new_message',
            messageId: message.id,
            loadId: loadId || '',
            senderId: senderId,
          },
        }),
      }
    )

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing message push:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
