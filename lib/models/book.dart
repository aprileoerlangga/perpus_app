import 'package:perpus_app/models/category.dart';

class Book {
  final int id;
  final String judul;
  final String pengarang;
  final String penerbit;
  final String tahun;
  final int stok;
  final Category category; // Properti ini sudah ada, kita hanya perlu memastikan cara membacanya benar

  Book({
    required this.id,
    required this.judul,
    required this.pengarang,
    required this.penerbit,
    required this.tahun,
    required this.stok,
    required this.category,
  });

  // --- PERBAIKAN UTAMA DI SINI ---
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? 0,
      judul: json['judul'] ?? 'Tanpa Judul',
      pengarang: json['pengarang'] ?? 'Tanpa Pengarang',
      penerbit: json['penerbit'] ?? 'Tanpa Penerbit',
      tahun: json['tahun']?.toString() ?? '-', // Ambil tahun sebagai string
      stok: json['stok'] ?? 0,
      // Logika untuk membaca data kategori:
      // Jika ada objek 'category' di dalam JSON, gunakan itu.
      // Jika tidak ada (seperti di daftar semua buku), buat kategori dummy dari 'category_id'.
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : Category(id: json['category_id'] ?? 0, name: 'Memuat...'),
    );
  }
}