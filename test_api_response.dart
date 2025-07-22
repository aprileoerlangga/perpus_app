import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://perpus-api.mamorasoft.com/api',
    connectTimeout: const Duration(milliseconds: 10000),
    receiveTimeout: const Duration(milliseconds: 10000),
    headers: {'Accept': 'application/json'},
  ));

  try {
    print('Testing API to get book data...');
    
    // Test getting book list first
    print('\n=== Testing Books List API ===');
    final booksResponse = await dio.get('/book');
    print('Books response status: ${booksResponse.statusCode}');
    
    if (booksResponse.data != null && 
        booksResponse.data is Map<String, dynamic> &&
        booksResponse.data['data'] != null &&
        booksResponse.data['data']['books'] is List) {
      
      final List books = booksResponse.data['data']['books'];
      print('Number of books found: ${books.length}');
      
      if (books.isNotEmpty) {
        final firstBook = books.first;
        print('\nFirst book structure:');
        print('Available fields: ${firstBook.keys.toList()}');
        
        // Check for image-related fields
        final imageFields = ['image_url', 'cover_image', 'foto_buku', 'gambar', 'image', 'cover'];
        print('\nChecking for image fields:');
        for (final field in imageFields) {
          if (firstBook.containsKey(field)) {
            print('✓ Found image field: $field = ${firstBook[field]}');
          } else {
            print('✗ No field: $field');
          }
        }
        
        // Test getting book detail
        if (firstBook['id'] != null) {
          print('\n=== Testing Book Detail API ===');
          final bookId = firstBook['id'];
          final detailResponse = await dio.get('/book/$bookId');
          print('Book detail response status: ${detailResponse.statusCode}');
          
          if (detailResponse.data != null &&
              detailResponse.data is Map<String, dynamic> &&
              detailResponse.data['data'] != null &&
              detailResponse.data['data']['book'] is Map<String, dynamic>) {
            
            final bookDetail = detailResponse.data['data']['book'];
            print('\nBook detail structure:');
            print('Available fields: ${bookDetail.keys.toList()}');
            
            // Check for image-related fields in detail
            print('\nChecking for image fields in detail:');
            for (final field in imageFields) {
              if (bookDetail.containsKey(field)) {
                print('✓ Found image field: $field = ${bookDetail[field]}');
              } else {
                print('✗ No field: $field');
              }
            }
          }
        }
      }
    }
    
  } catch (e) {
    print('Error testing API: $e');
  }
}
