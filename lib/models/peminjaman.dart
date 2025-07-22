import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/models/user.dart';

// Class ini merepresentasikan satu data peminjaman.
class Peminjaman {
  final int id;
  final String tanggalPinjam;
  final String tanggalKembali; // Batas tanggal pengembalian (due date)
  final String? tanggalPengembalian; // Tanggal aktual pengembalian (jika sudah dikembalikan)
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
    // Debug logging untuk melihat struktur data dengan detail yang lebih lengkap
    print('=== DEBUG PEMINJAMAN JSON ===');
    print('Full JSON: $json');
    print('ID: ${json['id']}');
    print('Status: ${json['status']}');
    print('tanggal_peminjaman: ${json['tanggal_peminjaman']}');
    print('batas_pengembalian: ${json['batas_pengembalian']}');
    print('due_date: ${json['due_date']}');
    print('tanggal_pengembalian: ${json['tanggal_pengembalian']}');
    print('return_date: ${json['return_date']}');
    print('tanggal_dikembalikan: ${json['tanggal_dikembalikan']}');
    if (json['book'] != null && json['book']['judul'] != null) {
      print('Book title: ${json['book']['judul']}');
    }
    print('===============================');
    
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
      tanggalPinjam: json['tanggal_peminjaman'] ?? '-',
      // Untuk batas tanggal kembali, gunakan field yang belum di-update oleh return
      tanggalKembali: json['batas_pengembalian'] ?? json['due_date'] ?? json['tanggal_pengembalian'] ?? '-', 
      // Untuk tanggal pengembalian aktual, hanya ada jika sudah dikembalikan (status 3)
      tanggalPengembalian: json['status']?.toString() == '3' ? 
                          (json['tanggal_pengembalian'] ?? json['return_date'] ?? json['tanggal_dikembalikan']) : 
                          null,
      status: json['status']?.toString() ?? 'unknown',
      user: json['member'] != null ? User.fromJson(json['member']) : defaultUser,
      book: json['book'] != null ? Book.fromJson(json['book']) : defaultBook,
    );
  }
}