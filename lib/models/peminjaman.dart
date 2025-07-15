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
    // Objek default ini akan mencegah error jika data 'user' atau 'book' tidak ada (null) dalam respons API.
    final defaultUser = User(id: 0, name: 'Pengguna Tidak Ditemukan', email: '', username: '');
    final defaultCategory = Category(id: 0, name: 'Tanpa Kategori');
    final defaultBook = Book(id: 0, judul: 'Buku Tidak Ditemukan', pengarang: '', penerbit: '', tahun: '', stok: 0, category: defaultCategory);

    return Peminjaman(
      id: json['id'] ?? 0,
      tanggalPinjam: json['tanggal_pinjam'] ?? '-',
      tanggalKembali: json['tanggal_kembali'] ?? '-',
      tanggalPengembalian: json['tanggal_pengembalian'],
      status: json['status'] ?? 'unknown',
      // Jika data user/book ada, gunakan itu. Jika tidak, gunakan objek default.
      user: json['user'] != null ? User.fromJson(json['user']) : defaultUser,
      book: json['book'] != null ? Book.fromJson(json['book']) : defaultBook,
    );
  }
}
