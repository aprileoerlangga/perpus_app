import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_saver/file_saver.dart';

class SimpleFileService {
  /// Simple file save for mobile with browser fallback
  static Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required BuildContext context,
  }) async {
    try {
      print('🔄 SimpleFileService: Starting save for $fileName (${bytes.length} bytes)');
      
      // For web, always use FileSaver (browser download)
      if (kIsWeb) {
        print('🌐 Web detected: Using FileSaver');
        return await _useBrowserDownload(fileName, bytes, context);
      }
      
      if (Platform.isAndroid) {
        // Try native Android save first
        bool nativeSuccess = await _saveAndroidFile(fileName, bytes, context);
        if (nativeSuccess) {
          return true;
        }
        
        // If native fails, ask user for browser fallback
        print('⚠️ Native Android save failed, offering browser option');
        return await _showBrowserFallbackDialog(fileName, bytes, context);
        
      } else if (Platform.isIOS) {
        return await _saveIOSFile(fileName, bytes, context);
      } else {
        print('❌ Unsupported platform');
        return false;
      }
    } catch (e) {
      print('❌ SimpleFileService error: $e');
      return false;
    }
  }

  static Future<bool> _showBrowserFallbackDialog(String fileName, Uint8List bytes, BuildContext context) async {
    if (!context.mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pilih Metode Download',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File tidak dapat disimpan ke folder Downloads. Pilih metode alternatif:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Browser option
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.web_rounded, size: 20),
                  label: const Text('Download via Browser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              // Cancel option  
              Container(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      return await _useBrowserDownload(fileName, bytes, context);
    }
    
    return false;
  }

  static Future<bool> _useBrowserDownload(String fileName, Uint8List bytes, BuildContext context) async {
    try {
      print('🌐 Using browser download for: $fileName');
      
      // Extract file extension
      String ext = fileName.split('.').last.toLowerCase();
      
      await FileSaver.instance.saveFile(
        name: fileName.split('.').first, // Remove extension, FileSaver adds it
        bytes: bytes,
        ext: ext,
      );
      
      print('✅ Browser download completed');
      
      if (context.mounted) {
        _showMessage(context, 'File berhasil didownload via browser: $fileName');
      }
      
      return true;
    } catch (e) {
      print('❌ Browser download failed: $e');
      if (context.mounted) {
        _showMessage(context, 'Download gagal: ${e.toString()}');
      }
      return false;
    }
  }

  static Future<bool> _saveAndroidFile(String fileName, Uint8List bytes, BuildContext context) async {
    try {
      // Check Android version
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkInt = androidInfo.version.sdkInt;
      
      print('📱 Android SDK: $sdkInt');

      // For Android 13+ (SDK 33+), no permission needed for Downloads
      if (sdkInt >= 33) {
        print('📱 Android 13+: No permission needed');
      } else {
        // Request storage permission for older versions
        PermissionStatus status = await Permission.storage.request();
        print('📝 Permission status: $status');
      }

      // Try to save to public Downloads directory first
      try {
        String downloadsPath = '/storage/emulated/0/Download';
        Directory downloadsDir = Directory(downloadsPath);
        
        if (await downloadsDir.exists()) {
          String filePath = '$downloadsPath/$fileName';
          File file = File(filePath);
          
          await file.writeAsBytes(bytes);
          print('✅ Saved to public Downloads: $filePath');
          
          // Verify file exists and has correct size
          if (await file.exists()) {
            int fileSize = await file.length();
            print('✅ File verified - Size: $fileSize bytes');
            
            if (context.mounted) {
              _showMessage(context, 'File berhasil disimpan ke Downloads: $fileName');
            }
            return true;
          }
        }
      } catch (e) {
        print('⚠️ Public Downloads failed: $e');
      }

      // Fallback: Save to app external directory  
      try {
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          String appDownloadsPath = '${externalDir.path}/Downloads';
          Directory appDownloadsDir = Directory(appDownloadsPath);
          
          if (!await appDownloadsDir.exists()) {
            await appDownloadsDir.create(recursive: true);
          }
          
          String filePath = '$appDownloadsPath/$fileName';
          File file = File(filePath);
          
          await file.writeAsBytes(bytes);
          print('✅ Saved to app Downloads: $filePath');
          
          if (await file.exists()) {
            int fileSize = await file.length();
            print('✅ App file verified - Size: $fileSize bytes');
            
            if (context.mounted) {
              _showMessage(context, 'File berhasil disimpan: $fileName\nLokasi: ${appDownloadsDir.path}');
            }
            return true;
          }
        }
      } catch (e) {
        print('❌ App Downloads failed: $e');
      }

      // Final fallback: Documents directory
      try {
        Directory documentsDir = await getApplicationDocumentsDirectory();
        String filePath = '${documentsDir.path}/$fileName';
        File file = File(filePath);
        
        await file.writeAsBytes(bytes);
        print('✅ Saved to documents: $filePath');
        
        if (await file.exists()) {
          int fileSize = await file.length();
          print('✅ Documents file verified - Size: $fileSize bytes');
          
          if (context.mounted) {
            _showMessage(context, 'File berhasil disimpan ke Documents: $fileName');
          }
          return true;
        }
      } catch (e) {
        print('❌ Documents save failed: $e');
      }

      print('❌ All Android save methods failed');
      return false; // Don't show error message, let caller handle fallback
      
    } catch (e) {
      print('❌ Android save error: $e');
      return false;
    }
  }

  static Future<bool> _saveIOSFile(String fileName, Uint8List bytes, BuildContext context) async {
    try {
      Directory documentsDir = await getApplicationDocumentsDirectory();
      String filePath = '${documentsDir.path}/$fileName';
      File file = File(filePath);
      
      await file.writeAsBytes(bytes);
      print('✅ iOS: Saved to documents: $filePath');
      
      if (await file.exists()) {
        int fileSize = await file.length();
        print('✅ iOS file verified - Size: $fileSize bytes');
        
        if (context.mounted) {
          _showMessage(context, 'File berhasil disimpan: $fileName');
        }
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ iOS save error: $e');
      return false;
    }
  }

  static void _showMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
