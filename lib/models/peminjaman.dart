import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/models/user.dart';

// Class ini merepresentasikan satu data peminjaman.
class Peminjaman {
  final int id;
  final String tanggalPinjam;
  final String tanggalKembali;
  final String? tanggalPengembalian; // Bisa null jika buku belum dikembalikan
  final String status;
  final User user; // Data peminjam
  final Book book; // Data buku yang dipinjam

  Peminjaman({
    required this.id,
    required this.tanggalPinjam,
    required this.tanggalKembali,
    this.tanggalPengembalian,
    required this.status,
    required this.user,
    required this.book,
  });

  // Factory constructor ini mengubah data JSON dari API menjadi objek Peminjaman.
  factory Peminjaman.fromJson(Map<String, dynamic> json) {
    final defaultUser = User(id: 0, name: 'Pengguna Tidak Ditemukan', email: '', username: '');
    final defaultBook = Book.fromJson({
      'id': 0,
      'judul': 'Buku Tidak Ditemukan',
      'pengarang': '',
      'penerbit': '',
      'tahun': '',
      'stok': 0,
      'category_id': 0
    });

    return Peminjaman(
      id: json['id'] ?? 0,
      // SESUAIKAN DENGAN KEY DARI JSON
      tanggalPinjam: json['tanggal_peminjaman'] ?? '-',
      tanggalKembali: json['tanggal_pengembalian'] ?? '-',
      tanggalPengembalian: json['tanggal_pengembalian'],
      status: json['status']?.toString() ?? 'unknown',
      // PERBAIKI: Gunakan key 'member' dari JSON, bukan 'user'
      user: json['member'] != null ? User.fromJson(json['member']) : defaultUser,
      book: json['book'] != null ? Book.fromJson(json['book']) : defaultBook,
    );
  }
}