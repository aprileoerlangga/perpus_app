import 'package:flutter/material.dart';
import '../utils/download_helper.dart';

class TestDownloadDialog extends StatelessWidget {
  const TestDownloadDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Test Download'),
      content: const Text('Test metode download seperti teman Anda'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            // Test dengan URL sample
            await DownloadHelper.downloadFile(
              url: 'http://perpus-api.mamorasoft.com/storage/exports/sample.pdf',
              fileName: 'test_download.pdf',
              context: context,
            );
            Navigator.pop(context);
          },
          child: const Text('Test Download'),
        ),
      ],
    );
  }
}

// Function to show test dialog
void showTestDownloadDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const TestDownloadDialog(),
  );
}
