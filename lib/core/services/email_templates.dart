/// Email HTML templates for Milow.
/// Note: Supabase hosted auth emails can be customized in the dashboard.
/// This file provides a rich template if you send your own via SMTP/Resend.
const String confirmationEmailHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Verify your email • Milow</title>
  <style>
    body { margin:0; padding:0; background:#0F172A; font-family: 'Inter', Arial, sans-serif; }
    .wrapper { width:100%; background:linear-gradient(135deg,#0F172A 0%,#1E3A8A 70%); padding:40px 0; }
    .container { max-width:560px; margin:0 auto; background:#FFFFFF; border-radius:28px; padding:48px 40px; box-shadow:0 12px 40px rgba(0,0,0,0.25); }
    h1 { font-size:28px; margin:0 0 12px; color:#101828; letter-spacing:-0.5px; }
    p { line-height:1.5; font-size:15px; color:#475467; margin:0 0 20px; }
    .button { display:inline-block; background:#007AFF; color:#FFFFFF !important; text-decoration:none; padding:16px 28px; font-weight:600; border-radius:14px; font-size:15px; letter-spacing:0.3px; box-shadow:0 4px 14px rgba(0,122,255,0.35); }
    .pill { background:#F0F8FF; color:#007AFF; font-weight:600; padding:6px 14px; border-radius:999px; font-size:12px; letter-spacing:0.5px; display:inline-block; margin-bottom:24px; }
    .footer { font-size:12px; color:#94A3B8; margin-top:40px; line-height:1.5; }
    .divider { height:1px; background:#EAECF0; margin:32px 0; }
    .brand { font-size:13px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; color:#007AFF; margin-bottom:16px; }
    a:hover.button { background:#0062C4; }
    @media (prefers-color-scheme: dark){
      .container { background:#1E293B; }
      h1 { color:#F9FAFB; }
      p { color:#CBD5E1; }
      .divider { background:#334155; }
      .footer { color:#64748B; }
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="brand">MILOW</div>
      <span class="pill">ACTION REQUIRED</span>
      <h1>Confirm your email</h1>
      <p>Hi there,<br><br>Thanks for joining Milow! Please verify your email address so we can unlock all features for your account.</p>
      <p>Click the button below — it only takes a second:</p>
      <p style="text-align:center;">
        <a class="button" href="{{ .ConfirmationURL }}" target="_blank" rel="noopener">Verify Email</a>
      </p>
      <div class="divider"></div>
      <p>If the button doesn't work, copy and paste this link into your browser:</p>
      <p style="word-break:break-all; font-size:12px; color:#667085;">{{ .ConfirmationURL }}</p>
      <p>This link will expire in 24 hours for security reasons.</p>
      <p class="footer">You received this email because a Milow account was created using this address. If this wasn't you, you can safely ignore it — no changes were made.<br><br>Need help? Reply to this email and our support team will assist you.</p>
    </div>
  </div>
</body>
</html>
''';

const String emailVerifiedSuccessSnippet =
    '<div style="background:#ECFDF5;padding:16px;border-radius:12px;font-family:Inter,Arial,sans-serif;font-size:14px;color:#047857;">✅ Your email was successfully verified. Welcome aboard!</div>';
