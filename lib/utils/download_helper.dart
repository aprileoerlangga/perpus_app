import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadHelper {
  /// Direct browser download - open URL in Chrome/browser
  static Future<void> downloadFile({
    required String url,
    required String fileName,
    required BuildContext context,
  }) async {
    try {
      print('🌐 Opening download URL in browser: $url');
      
      // Parse URL
      final uri = Uri.parse(url);
      
      // Launch URL in browser for direct download
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Force open in browser
        );
        
        print('✅ Successfully opened download URL in browser');
        
        // Show success message
        if (context.mounted) {
          _showSuccess(context, 'File akan didownload melalui browser: $fileName');
        }
      } else {
        print('❌ Cannot launch URL: $url');
        if (context.mounted) {
          _showError(context, 'Tidak dapat membuka URL download');
        }
      }
    } catch (e) {
      print('❌ Download error: $e');
      if (context.mounted) {
        _showError(context, 'Gagal membuka download: ${e.toString()}');
      }
    }
  }

  /// Show success message to user
  static void _showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show error message to user
  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Alternative method for web platform
  static Future<void> openUrlInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
