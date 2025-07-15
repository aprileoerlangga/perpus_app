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
      // Gunakan operator '??' untuk memberi nilai default jika null
      id: json['id'] ?? 0, 
      judul: json['judul'] ?? 'Tanpa Judul',
      pengarang: json['pengarang'] ?? 'Tanpa Pengarang',
      penerbit: json['penerbit'] ?? 'Tanpa Penerbit',
      tahun: json['tahun'] ?? '-',
      stok: json['stok'] ?? 0, 
      
      // Beri penanganan khusus jika seluruh objek kategori null
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : Category(id: 0, name: 'Tanpa Kategori'),
    );
  }
}