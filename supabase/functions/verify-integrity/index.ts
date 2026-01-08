// Supabase Edge Function: verify-integrity
// Verifies Google Play Integrity tokens server-side
//
// To deploy: supabase functions deploy verify-integrity
// Required secrets: GOOGLE_SERVICE_ACCOUNT_KEY

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Google Play Integrity API endpoint
const PLAY_INTEGRITY_API = 'https://playintegrity.googleapis.com/v1'

interface IntegrityRequest {
    integrityToken: string
}

interface IntegrityVerdict {
    deviceIntegrity?: {
        deviceRecognitionVerdict?: string[]
    }
    appIntegrity?: {
        appRecognitionVerdict?: string
        packageName?: string
        certificateSha256Digest?: string[]
        versionCode?: string
    }
    accountDetails?: {
        appLicensingVerdict?: string
    }
    requestDetails?: {
        requestHash?: string
        timestampMillis?: string
        requestPackageName?: string
    }
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { integrityToken } = await req.json() as IntegrityRequest

        if (!integrityToken) {
            return new Response(
                JSON.stringify({ valid: false, message: 'Missing integrity token' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Get Google access token using service account
        const accessToken = await getGoogleAccessToken()
        if (!accessToken) {
            return new Response(
                JSON.stringify({ valid: false, message: 'Failed to authenticate with Google' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Decode the integrity token with Google's API
        const packageName = 'maninder.co.in.milow' // Your app's package name
        const decodeResponse = await fetch(
            `${PLAY_INTEGRITY_API}/${packageName}:decodeIntegrityToken`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ integrity_token: integrityToken }),
            }
        )

        if (!decodeResponse.ok) {
            const errorText = await decodeResponse.text()
            console.error('Google API error:', errorText)
            return new Response(
                JSON.stringify({ valid: false, message: 'Failed to verify token with Google' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const tokenPayload = await decodeResponse.json()
        const verdict: IntegrityVerdict = tokenPayload.tokenPayloadExternal || {}

        // Validate the verdict
        const validationResult = validateVerdict(verdict, packageName)

        return new Response(
            JSON.stringify({
                valid: validationResult.isValid,
                message: validationResult.message,
                verdict: {
                    deviceIntegrity: verdict.deviceIntegrity?.deviceRecognitionVerdict?.join(', ') || 'unknown',
                    appIntegrity: verdict.appIntegrity?.appRecognitionVerdict || 'unknown',
                    licensing: verdict.accountDetails?.appLicensingVerdict || 'unknown',
                },
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error) {
        console.error('Verification error:', error)
        return new Response(
            JSON.stringify({ valid: false, message: `Server error: ${error.message}` }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

// Get Google access token using service account credentials
async function getGoogleAccessToken(): Promise<string | null> {
    try {
        const serviceAccountKey = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_KEY')
        if (!serviceAccountKey) {
            console.error('Missing GOOGLE_SERVICE_ACCOUNT_KEY secret')
            return null
        }

        const credentials = JSON.parse(serviceAccountKey)

        // Create JWT for Google OAuth
        const now = Math.floor(Date.now() / 1000)
        const payload = {
            iss: credentials.client_email,
            scope: 'https://www.googleapis.com/auth/playintegrity',
            aud: 'https://oauth2.googleapis.com/token',
            iat: now,
            exp: now + 3600,
        }

        // Sign the JWT
        const header = { alg: 'RS256', typ: 'JWT' }
        const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
        const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

        const signatureInput = `${encodedHeader}.${encodedPayload}`

        // Import the private key and sign
        const privateKey = await crypto.subtle.importKey(
            'pkcs8',
            pemToArrayBuffer(credentials.private_key),
            { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
            false,
            ['sign']
        )

        const signature = await crypto.subtle.sign(
            'RSASSA-PKCS1-v1_5',
            privateKey,
            new TextEncoder().encode(signatureInput)
        )

        const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
            .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

        const jwt = `${signatureInput}.${encodedSignature}`

        // Exchange JWT for access token
        const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
        })

        if (!tokenResponse.ok) {
            console.error('Token exchange failed:', await tokenResponse.text())
            return null
        }

        const tokenData = await tokenResponse.json()
        return tokenData.access_token
    } catch (error) {
        console.error('Error getting access token:', error)
        return null
    }
}

// Convert PEM to ArrayBuffer for crypto.subtle
function pemToArrayBuffer(pem: string): ArrayBuffer {
    const base64 = pem
        .replace('-----BEGIN PRIVATE KEY-----', '')
        .replace('-----END PRIVATE KEY-----', '')
        .replace(/\s/g, '')
    const binary = atob(base64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i)
    }
    return bytes.buffer
}

// Validate the integrity verdict
function validateVerdict(verdict: IntegrityVerdict, expectedPackageName: string): { isValid: boolean; message: string } {
    // Check device integrity
    const deviceVerdict = verdict.deviceIntegrity?.deviceRecognitionVerdict || []
    const hasBasicIntegrity = deviceVerdict.includes('MEETS_BASIC_INTEGRITY')
    const hasDeviceIntegrity = deviceVerdict.includes('MEETS_DEVICE_INTEGRITY')

    if (!hasBasicIntegrity) {
        return { isValid: false, message: 'Device does not meet basic integrity' }
    }

    // Check app integrity
    const appVerdict = verdict.appIntegrity?.appRecognitionVerdict
    if (appVerdict === 'UNRECOGNIZED_VERSION' || appVerdict === 'UNEVALUATED') {
        // For warn-only mode, we allow unrecognized versions
        console.log('App integrity warning:', appVerdict)
    }

    // Check package name matches
    const packageName = verdict.appIntegrity?.packageName || verdict.requestDetails?.requestPackageName
    if (packageName && packageName !== expectedPackageName) {
        return { isValid: false, message: 'Package name mismatch' }
    }

    // All checks passed
    return { isValid: true, message: 'Integrity verified' }
}
