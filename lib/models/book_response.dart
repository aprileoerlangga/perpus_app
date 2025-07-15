import 'package:perpus_app/models/book.dart';

class BookResponse {
  final List<Book> books;
  final bool hasMore;

  BookResponse({required this.books, required this.hasMore});
}