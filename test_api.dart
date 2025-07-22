import 'package:perpus_app/api/api_service.dart';

void main() async {
  final apiService = ApiService();
  
  try {
    print('Testing API endpoints...');
    
    // Test books endpoint
    final booksResponse = await apiService.getBooks(page: 1);
    print('Books page 1: ${booksResponse.books.length}');
    print('Has more books: ${booksResponse.hasMore}');
    
    // Test if there are more pages
    if (booksResponse.hasMore) {
      final booksPage2 = await apiService.getBooks(page: 2);
      print('Books page 2: ${booksPage2.books.length}');
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
