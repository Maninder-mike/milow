import 'package:fluent_ui/fluent_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingVerificationPage extends StatefulWidget {
  const PendingVerificationPage({super.key});

  @override
  State<PendingVerificationPage> createState() =>
      _PendingVerificationPageState();
}

class _PendingVerificationPageState extends State<PendingVerificationPage> {
  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fluentTheme.brightness == Brightness.light
          ? Colors.white
          : Colors.black,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: fluentTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fluentTheme.resources.dividerStrokeColorDefault,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: fluentTheme.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.lock,
                  size: 48,
                  color: fluentTheme.accentColor,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Verification Pending',
                style: FluentTheme.of(
                  context,
                ).typography.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Your account has been created and is waiting for administrator approval.\n\n'
                'A notification has been sent to Administrators at @${Supabase.instance.client.auth.currentUser?.email?.split('@').last ?? 'your domain'}.\n'
                'Please wait for approval.',
                style: FluentTheme.of(context).typography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HyperlinkButton(
                    onPressed: () {
                      // Trigger a redirect check or just show info
                      displayInfoBar(
                        context,
                        builder: (context, close) {
                          return InfoBar(
                            title: const Text('Checking Status...'),
                            content: const Text(
                              'If approved, you will be redirected shortly.',
                            ),
                            action: IconButton(
                              icon: const Icon(FluentIcons.clear),
                              onPressed: close,
                            ),
                          );
                        },
                      );
                      // In GoRouter logic, a refresh might be needed, but usually Supabase auth state change triggers it.
                      // Metadata updates don't always trigger auth state change streams unless explicitly refreshed.
                      Supabase.instance.client.auth.refreshSession();
                    },
                    child: const Text('Check Status'),
                  ),
                  const SizedBox(width: 16),
                  HyperlinkButton(
                    onPressed: _signOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  FluentThemeData get fluentTheme => FluentTheme.of(context);
}
