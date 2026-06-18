import { serve } from 'std/http/server'
import { createClient } from 'supabase'
import { JWT } from 'google-auth-library'

interface PushNotificationPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, string>
}

serve(async (req) => {
  try {
    const { user_id, title, body, data }: PushNotificationPayload = await req.json()

    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Get FCM token for the user
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('fcm_token')
      .eq('id', user_id)
      .single()

    if (profileError || !profile?.fcm_token) {
      console.log(`No FCM token found for user ${user_id}`)
      return new Response(JSON.stringify({ success: false, message: 'No FCM token' }), { status: 200 })
    }

    // 2. Prepare FCM payload
    const fcmToken = profile.fcm_token
    const message = {
      message: {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      },
    }

    // 3. Get Access Token for FCM HTTP v1
    // Note: FIREBASE_SERVICE_ACCOUNT_KEY must be a JSON string in Supabase Vault
    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY') || '{}')
    const jwt = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    })

    const tokenResponse = await jwt.getAccessToken()
    const accessToken = tokenResponse.token

    if (!accessToken) {
      throw new Error('Failed to get FCM access token')
    }

    // 4. Send to FCM
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      }
    )

    const fcmResult = await fcmResponse.json()
    console.log('FCM result:', fcmResult)

    return new Response(JSON.stringify(fcmResult), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error sending push:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
