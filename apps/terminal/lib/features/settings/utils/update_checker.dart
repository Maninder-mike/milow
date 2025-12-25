import 'package:fluent_ui/fluent_ui.dart';

Future<void> checkForUpdates(BuildContext context) async {
  showDialog(
    context: context,
    builder: (context) {
      // Simulated update check
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          Navigator.pop(context); // Close checking dialog
          showDialog(
            context: context,
            builder: (context) => ContentDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0078D4), // Fluent Blue
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'i',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Expanded(
                    child: Text(
                      'There are currently no updates available.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              actions: [
                Button(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      });

      return const ContentDialog(
        title: Text('Checking for updates...'),
        content: SizedBox(height: 50, child: Center(child: ProgressBar())),
      );
    },
  );
}
