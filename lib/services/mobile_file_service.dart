import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class MobileFileService {
  static final MobileFileService _instance = MobileFileService._();
  factory MobileFileService() => _instance;
  MobileFileService._();

  /// Request necessary permissions for file access
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      print('🍎 iOS detected - no permission needed');
      return true; // iOS handles permissions differently
    }

    try {
      // Check Android version first
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      
      print('🤖 Android SDK: ${androidInfo.version.sdkInt}');
      
      // Android 13+ (API 33+) handles storage differently
      if (androidInfo.version.sdkInt >= 33) {
        print('✅ Android 13+ detected - storage permission handled by system');
        return true;
      }
      
      // For Android 10-12, we need storage permissions
      print('📝 Checking storage permission for Android ${androidInfo.version.sdkInt}');
      
      // Check current permission status
      PermissionStatus status = await Permission.storage.status;
      print('📋 Current permission status: $status');
      
      if (status == PermissionStatus.granted) {
        print('✅ Storage permission already granted');
        return true;
      }
      
      // Request permission
      print('🙏 Requesting storage permission...');
      status = await Permission.storage.request();
      print('📋 Permission after request: $status');
      
      // Handle different status responses
      switch (status) {
        case PermissionStatus.granted:
          print('✅ Storage permission granted');
          return true;
        case PermissionStatus.denied:
          print('⚠️ Storage permission denied - trying to continue anyway');
          return true; // Try to continue, might work on some devices
        case PermissionStatus.permanentlyDenied:
          print('❌ Storage permission permanently denied');
          return false;
        case PermissionStatus.restricted:
          print('⚠️ Storage permission restricted - trying to continue anyway');
          return true; // Try to continue
        default:
          print('⚠️ Unknown permission status: $status - trying to continue anyway');
          return true; // Try to continue
      }
      
    } catch (e) {
      print('⚠️ Error requesting permission: $e - trying to continue anyway');
      // If permission checking fails, try to proceed anyway
      // Some devices might work without explicit permission
      return true;
    }
  }

  /// Save file to Downloads directory with proper mobile handling
  Future<bool> saveFileToDownloads({
    required String fileName,
    required Uint8List bytes,
    required BuildContext context,
  }) async {
    try {
      print('🔄 Starting file save process for: $fileName (${bytes.length} bytes)');
      
      // Request permission first (will auto-pass for Android 13+)
      bool hasPermission = await requestStoragePermission();
      print('📝 Permission status: $hasPermission');
      
      if (!hasPermission) {
        print('❌ Permission denied');
        if (context.mounted) {
          _showPermissionDialog(context);
        }
        return false;
      }

      String? filePath;
      
      if (Platform.isAndroid) {
        print('🤖 Android detected - trying multiple save methods...');
        filePath = await _saveFileAndroid(fileName, bytes);
      } else if (Platform.isIOS) {
        print('🍎 iOS detected - saving to documents...');
        filePath = await _saveFileIOS(fileName, bytes);
      }

      if (filePath == null) {
        print('❌ Could not save file - all methods failed');
        if (context.mounted) {
          _showErrorDialog(context, 'Tidak dapat menyimpan file ke storage device');
        }
        return false;
      }

      print('✅ File saved successfully: $filePath');
      
      // Verify file exists
      File savedFile = File(filePath);
      bool fileExists = await savedFile.exists();
      int fileSize = fileExists ? await savedFile.length() : 0;
      
      print('🔍 File verification: exists=$fileExists, size=$fileSize bytes');
      
      if (!fileExists || fileSize == 0) {
        print('❌ File verification failed');
        if (context.mounted) {
          _showErrorDialog(context, 'File tidak tersimpan dengan benar');
        }
        return false;
      }
      
      // Show success message with file location
      if (context.mounted) {
        _showSuccessDialog(context, filePath, fileName);
      }
      
      return true;
      
    } catch (e) {
      print('💥 Error saving file: $e');
      if (context.mounted) {
        _showErrorDialog(context, 'Error: $e');
      }
      return false;
    }
  }
  
  /// Save file for Android with multiple fallback methods
  Future<String?> _saveFileAndroid(String fileName, Uint8List bytes) async {
    print('🔄 Trying Android save methods...');
    
    // Method 1: Try Downloads directory directly
    try {
      print('📁 Method 1: Direct Downloads folder (/storage/emulated/0/Download)');
      String downloadsPath = '/storage/emulated/0/Download';
      Directory downloadsDir = Directory(downloadsPath);
      
      if (await downloadsDir.exists()) {
        print('✅ Downloads directory exists');
        String filePath = '$downloadsPath/$fileName';
        File file = File(filePath);
        await file.writeAsBytes(bytes);
        
        // Verify write
        bool exists = await file.exists();
        int size = exists ? await file.length() : 0;
        print('🔍 Method 1 verification: exists=$exists, size=$size');
        
        if (exists && size > 0) {
          print('✅ Method 1 SUCCESS: Direct Downloads');
          return filePath;
        }
      } else {
        print('❌ Downloads directory does not exist');
      }
    } catch (e) {
      print('❌ Method 1 failed: $e');
    }
    
    // Method 2: Try external storage Downloads via getExternalStorageDirectory
    try {
      print('📁 Method 2: External storage Downloads');
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        print('📂 External dir: ${externalDir.path}');
        // Try to navigate to public Downloads
        List<String> pathVariants = [
          '${externalDir.parent.parent.parent.parent.path}/Download',
          '${externalDir.parent.parent.parent.parent.path}/Downloads',
          '/storage/emulated/0/Download',
          '/sdcard/Download',
        ];
        
        for (String downloadsPath in pathVariants) {
          try {
            print('🔍 Trying path: $downloadsPath');
            if (await Directory(downloadsPath).exists()) {
              String filePath = '$downloadsPath/$fileName';
              File file = File(filePath);
              await file.writeAsBytes(bytes);
              
              // Verify write
              bool exists = await file.exists();
              int size = exists ? await file.length() : 0;
              print('🔍 Method 2 verification: exists=$exists, size=$size');
              
              if (exists && size > 0) {
                print('✅ Method 2 SUCCESS: External Downloads ($downloadsPath)');
                return filePath;
              }
            }
          } catch (e) {
            print('⚠️ Path $downloadsPath failed: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Method 2 failed: $e');
    }
    
    // Method 3: App external storage with Downloads folder
    try {
      print('📁 Method 3: App external Downloads folder');
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        String downloadsPath = '${externalDir.path}/Downloads';
        await Directory(downloadsPath).create(recursive: true);
        String filePath = '$downloadsPath/$fileName';
        File file = File(filePath);
        await file.writeAsBytes(bytes);
        
        // Verify write
        bool exists = await file.exists();
        int size = exists ? await file.length() : 0;
        print('🔍 Method 3 verification: exists=$exists, size=$size');
        
        if (exists && size > 0) {
          print('✅ Method 3 SUCCESS: App external Downloads folder');
          return filePath;
        }
      }
    } catch (e) {
      print('❌ Method 3 failed: $e');
    }
    
    // Method 4: App documents directory (last resort)
    try {
      print('📁 Method 4: App documents directory (fallback)');
      final Directory appDir = await getApplicationDocumentsDirectory();
      String filePath = '${appDir.path}/$fileName';
      File file = File(filePath);
      await file.writeAsBytes(bytes);
      
      // Verify write
      bool exists = await file.exists();
      int size = exists ? await file.length() : 0;
      print('🔍 Method 4 verification: exists=$exists, size=$size');
      
      if (exists && size > 0) {
        print('✅ Method 4 SUCCESS: App documents directory');
        return filePath;
      }
    } catch (e) {
      print('❌ Method 4 failed: $e');
    }
    
    print('💥 All Android save methods failed');
    return null;
  }
  
  /// Save file for iOS
  Future<String?> _saveFileIOS(String fileName, Uint8List bytes) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      String filePath = '${appDir.path}/$fileName';
      File file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('iOS save failed: $e');
      return null;
    }
  }

  /// Show permission dialog
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Diperlukan'),
          content: const Text(
            'Aplikasi membutuhkan izin akses storage untuk menyimpan file. '
            'Silakan berikan izin di pengaturan aplikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        );
      },
    );
  }

  /// Show success dialog with file location
  void _showSuccessDialog(BuildContext context, String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('✅ File Berhasil Disimpan!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nama File:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder, color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('Lokasi File:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (filePath.contains('/storage/emulated/0/Download'))
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.download_rounded, color: Colors.green.shade600, size: 16),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Folder Download (mudah diakses)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_special, color: Colors.yellow.shade700, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Folder Aplikasi',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Akses via: File Manager > Android > data > com.example.perpus_app',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tip: Gunakan aplikasi File Manager untuk menemukan file yang diunduh',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show error dialog
  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('❌ Error'),
          content: Text('Gagal menyimpan file: $error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Get readable file size
  String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
}
