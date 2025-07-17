import 'package:perpus_app/models/category.dart';

class Book {
  final int id;
  final String judul;
  final String pengarang;
  final String penerbit;
  final String tahun;
  final int stok;
  final Category category;

  Book({
    required this.id,
    required this.judul,
    required this.pengarang,
    required this.penerbit,
    required this.tahun,
    required this.stok,
    required this.category,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? 0,
      judul: json['judul'] ?? 'Tanpa Judul',
      pengarang: json['pengarang'] ?? 'Tanpa Pengarang',
      penerbit: json['penerbit'] ?? 'Tanpa Penerbit',
      tahun: json['tahun'] ?? '-',
      stok: json['stok'] ?? 0,
      // PERBAIKAN: Buat objek Category dummy karena API tidak menyediakannya di sini
      category: Category(
        id: json['category_id'] ?? 0,
        name: 'Kategori', // Anda bisa beri nama default atau kosong
      ),
    );
  }
}