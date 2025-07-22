import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'lib/api/api_service.dart';

void main() async {
  print('🧪 Testing Image Upload Feature');
  
  // Create API service instance
  final apiService = ApiService();
  
  // Test data
  Map<String, String> bookData = {
    'judul': 'Test Book',
    'category_id': '1',
    'pengarang': 'Test Author',
    'penerbit': 'Test Publisher', 
    'tahun': '2024',
    'stok': '5',
  };
  
  print('📝 Book data prepared: $bookData');
  
  try {
    // Test without image first
    print('🧪 Testing book creation without image...');
    bool success = await apiService.addBook(bookData);
    print('✅ Book without image: $success');
    
    // Note: For image testing, you would need to:
    // 1. Pick an image using ImagePicker
    // 2. Pass it to addBook function
    print('📷 For image testing, use the app UI to pick and upload images');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
