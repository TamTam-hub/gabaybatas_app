import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/gb_dialog.dart';
import 'update_service.dart';

/// Tells the resident a newer version is ready. "Update" downloads the APK in
/// the browser; the resident then opens it and Android asks to install.
Future<void> showUpdatePrompt(BuildContext context, AppUpdate update) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return GbDialog(
        icon: Icons.system_update_rounded,
        title: 'Update available',
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GabayBatas ${update.version} is ready. '
                  'You have version ${update.currentVersion}.',
                ),
                if (update.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "What's new",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    update.notes,
                    style: const TextStyle(
                      color: Color(0xFF5F7396),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'After the download finishes, open the file and tap Install. '
                  'If your phone asks, allow installing apps from your browser.',
                  style: TextStyle(color: Color(0xFF5F7396), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final opened = await launchUrl(
                Uri.parse(update.downloadUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open the download. Please try again later.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Update'),
          ),
        ],
      );
    },
  );
}
