import 'package:perpus_app/api/api_service.dart';

void main() async {
  final apiService = ApiService();
  
  print("Testing category functionality...");
  
  try {
    // Test getting all categories
    print("1. Getting all categories...");
    final categories = await apiService.getCategories();
    print("Found ${categories.length} categories:");
    for (var category in categories) {
      print("  - ${category.name} (ID: ${category.id})");
    }
    
    // Test getting books
    print("\n2. Getting all books...");
    final allBooks = await apiService.getBooks();
    print("Found ${allBooks.books.length} books total");
    
    // Test filtering books by category
    if (categories.isNotEmpty) {
      final firstCategory = categories.first;
      print("\n3. Getting books for category '${firstCategory.name}'...");
      final filteredBooks = await apiService.getBooks(categoryId: firstCategory.id);
      print("Found ${filteredBooks.books.length} books in this category:");
      for (var book in filteredBooks.books) {
        print("  - ${book.judul} (Category: ${book.category.name})");
      }
    }
    
    print("\nCategory functionality test completed successfully!");
  } catch (e) {
    print("Error during testing: $e");
  }
}
