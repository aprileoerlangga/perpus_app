import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/screens/book/book_form_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Book> _bookFuture;

  @override
  void initState() {
    super.initState();
    _loadBookDetail();
  }

  // Fungsi untuk memuat atau memuat ulang detail buku
  void _loadBookDetail() {
    setState(() {
      _bookFuture = _apiService.getBookById(widget.bookId);
    });
  }

  // Fungsi untuk menghapus buku
  void _deleteBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus buku ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final success = await _apiService.deleteBook(widget.bookId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buku berhasil dihapus')));
          // Kembali ke halaman list dan kirim sinyal refresh
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus buku')));
        }
      }
    }
  }

  // == FUNGSI BARU UNTUK NAVIGASI KE HALAMAN EDIT ==
  void _navigateToEditPage(Book book) async {
    // Navigasi ke FormScreen dan kirim data buku yang akan diedit
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookFormScreen(book: book)),
    );

    // Jika kembali dengan sinyal 'true' (artinya update berhasil),
    // maka muat ulang detail buku untuk menampilkan data terbaru.
    if (result == true) {
      _loadBookDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Buku'),
        actions: [
          // Tombol Edit dan Delete akan muncul di sini
          FutureBuilder<Book>(
            future: _bookFuture,
            builder: (context, snapshot) {
              // Hanya tampilkan tombol jika data sudah berhasil dimuat
              if (snapshot.hasData) {
                return Row(
                  children: [
                    // == TOMBOL EDIT BARU ==
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _navigateToEditPage(snapshot.data!),
                      tooltip: 'Edit Buku',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _deleteBook,
                      tooltip: 'Hapus Buku',
                    ),
                  ],
                );
              }
              // Sembunyikan tombol jika data sedang loading atau error
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<Book>(
        future: _bookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Data tidak ditemukan.'));
          }
          final book = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                    child: Icon(Icons.menu_book, size: 80, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(height: 24),
                Text(book.judul, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('oleh ${book.pengarang}', style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey)),
                const Divider(height: 40, thickness: 1),
                _buildDetailRow('Penerbit', book.penerbit),
                _buildDetailRow('Kategori', book.category.name),
                _buildDetailRow('Tahun Terbit', book.tahun),
                _buildDetailRow('Stok Tersedia', '${book.stok} buah'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const Text(':', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}