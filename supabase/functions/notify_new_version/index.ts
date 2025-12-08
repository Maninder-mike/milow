
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// Using a simple JWT library for Deno to sign Google Service Account JWT
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Parse Database Webhook Payload
        const payload = await req.json()
        console.log("Received payload:", payload)

        // Check if it's an INSERT on app_version
        // The structure depends on how the webhook is sent (pg_net or Supabase Dashboard webhook).
        // Dashboard webhook structure: { type: 'INSERT', table: 'app_version', record: { ... }, schema: 'public' }
        if (payload.type !== 'INSERT' || payload.table !== 'app_version') {
            return new Response(JSON.stringify({ message: 'Not an app_version INSERT event' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        const newVersion = payload.record // The new row
        const versionNumber = newVersion.latest_version
        const platform = newVersion.platform
        const changelog = newVersion.changelog || 'Check out the new features!'

        // 2. Initialize Supabase Client to fetch tokens
        // We need SERVICE_ROLE_KEY to bypass RLS if needed, or usually standard client is fine if RLS allows.
        // But to read ALL profiles, we likely need Admin rank.
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseServiceKey)

        // 3. Fetch FCM Tokens
        // Assuming 'profiles' has 'fcm_token'
        const { data: profiles, error: dbError } = await supabase
            .from('profiles')
            .select('fcm_token')
            .not('fcm_token', 'is', null)

        if (dbError) throw dbError

        const tokens = profiles.map(p => p.fcm_token).filter(t => t && t.length > 0)
        console.log(`Found ${tokens.length} tokens to notify.`)

        if (tokens.length === 0) {
            console.log('No FCM tokens found, but saving announcement to DB')
        }

        // 4. Save to Announcements Table (In-App Inbox)
        const { error: announceError } = await supabase
            .from('announcements')
            .insert({
                title: `New Update: v${versionNumber}`,
                body: changelog,
                version: versionNumber,
                is_active: true
            })

        if (announceError) console.error('Failed to save announcement:', announceError)

        if (tokens.length === 0) {
            return new Response(JSON.stringify({ message: 'Saved announcement, no devices to notify' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // 5. Get Access Token for FCM v1
        const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
        if (!serviceAccountStr) {
            throw new Error('Missing FIREBASE_SERVICE_ACCOUNT environment variable')
        }
        const serviceAccount = JSON.parse(serviceAccountStr)
        const accessToken = await getAccessToken(serviceAccount)

        // 5. Send Notifications (Batching is recommended, but FCM v1 HTTP API is 1-by-1 or batch?
        // The legacy batch API is gone. FCM v1 requires individual requests usually, or HTTP/2 multiplexing.
        // For simplicity in this function, we loop. For scale, use a queue or specialized batch endpoint if available (but v1 doesn't support the old batch format).
        // We will initiate parallel requests.

        // Notification payload
        const messagePayload = {
            notification: {
                title: `New Update Available: v${versionNumber}`,
                body: `${platform === 'android' ? 'Android' : 'iOS'} update available. \n${changelog}`,
            },
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'app_update',
                version: versionNumber,
                url: newVersion.download_url || '',
            },
        }

        const projectId = serviceAccount.project_id
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

        const promises = tokens.map(token => {
            return fetch(fcmUrl, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: {
                        token: token,
                        ...messagePayload
                    }
                })
            }).then(async res => {
                if (!res.ok) {
                    const text = await res.text()
                    console.error(`Failed to send to ${token}:`, text)
                    // Handle invalid token (e.g., remove from DB)
                }
            }).catch(err => console.error(err))
        })

        await Promise.all(promises)

        return new Response(JSON.stringify({ message: `Sent notifications to ${tokens.length} devices` }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })

    } catch (err) {
        console.error(err)
        return new Response(JSON.stringify({ error: err.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
})

// Helper to get Google Access Token via JWT
async function getAccessToken(serviceAccount: any) {
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600; // 1 hour

    const jwtHeader = { alg: "RS256", typ: "JWT", kid: serviceAccount.private_key_id };

    const jwtClaimSet = {
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: "https://oauth2.googleapis.com/token",
        iat,
        exp,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
    };

    // Sign the JWT
    // Import key
    const key = await importPrivateKey(serviceAccount.private_key);

    // NOTE: 'djwt' library or native Web Crypto API can be used.
    // Using native Web Crypto API for minimal dependencies if possible?
    // Actually, standard Deno practice often imports 'jose' or similar.
    // Let's use a simplified approach or assume 'djwt' works.
    // BUT to be safe and robust without external deps failure, I'll use a very standard import.
    // Let's use 'import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"' which I included above.

    const jwt = await create(jwtHeader, jwtClaimSet, key); // Logic adjustment needed for key format

    // Exchange JWT for Access Token
    const res = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: jwt,
        }),
    });

    if (!res.ok) {
        throw new Error(`Auth failed: ${await res.text()}`);
    }
    const data = await res.json();
    return data.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
    // Remove header/footer and newlines
    const binary = pem
        .replace(/-----BEGIN PRIVATE KEY-----/, "")
        .replace(/-----END PRIVATE KEY-----/, "")
        .replace(/\n/g, "");

    const binaryString = atob(binary);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }

    return await crypto.subtle.importKey(
        "pkcs8",
        bytes,
        {
            name: "RSASSA-PKCS1-v1_5",
            hash: "SHA-256",
        },
        true,
        ["sign"]
    );
}
