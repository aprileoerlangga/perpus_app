import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';

class MyPeminjamanListScreen extends StatefulWidget {
  const MyPeminjamanListScreen({super.key});

  @override
  State<MyPeminjamanListScreen> createState() => _MyPeminjamanListScreenState();
}

class _MyPeminjamanListScreenState extends State<MyPeminjamanListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Peminjaman> _peminjamanList = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    print("--- Membuka Halaman Riwayat Peminjaman Saya ---");
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore && _hasMore && !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _peminjamanList = [];
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = '';
    });
    try {
      print("Memanggil API getMyPeminjamanList untuk halaman $_currentPage...");
      final PeminjamanResponse response = await _apiService.getMyPeminjamanList(page: _currentPage);
      setState(() {
        _peminjamanList = response.peminjamanList;
        _hasMore = response.hasMore;
        _isLoading = false;
        print("API Berhasil: Ditemukan ${_peminjamanList.length} data peminjaman.");
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        print("API Gagal: $e");
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _loadMore() async {
    setState(() { _isLoadingMore = true; });
    try {
      print("Memanggil API getMyPeminjamanList untuk halaman berikutnya (${_currentPage + 1})...");
      final PeminjamanResponse response = await _apiService.getMyPeminjamanList(page: _currentPage + 1);
      setState(() {
        _peminjamanList.addAll(response.peminjamanList);
        _currentPage++;
        _hasMore = response.hasMore;
        _isLoadingMore = false;
        print("API Load More Berhasil: Total data sekarang ${_peminjamanList.length}.");
      });
    } catch (e) {
      setState(() { _isLoadingMore = false; });
       print("API Load More Gagal: $e");
    }
  }

  // --- UBAH FUNGSI INI ---
  Future<void> _handleReturnBook(int peminjamanId) async {
    // Dapatkan tanggal hari ini untuk ditampilkan di dialog
    final String tanggalHariIni = 
        MaterialLocalizations.of(context).formatFullDate(DateTime.now());

    // Tampilkan dialog konfirmasi
    final bool? shouldReturn = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User harus memilih salah satu tombol
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pengembalian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anda akan mengembalikan buku ini. Apakah Anda yakin?'),
            const SizedBox(height: 16),
            Text(
              'Tanggal Pengembalian: $tanggalHariIni',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Ya, Kembalikan'),
          ),
        ],
      ),
    );

    // Jika user menekan "Batal" (atau menutup dialog), hentikan proses
    if (shouldReturn == null || !shouldReturn) return;

    // Tampilkan loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memproses pengembalian...'))
    );

    // Panggil API untuk mengembalikan buku
    bool success = await _apiService.returnBook(peminjamanId);

    // Hapus loading indicator
    if (mounted) ScaffoldMessenger.of(context).removeCurrentSnackBar();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buku berhasil dikembalikan!'),
            backgroundColor: Colors.green,
          ),
        );
        // Muat ulang data untuk melihat perubahan status
        _loadInitial(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengembalikan buku.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buku Pinjaman Saya')),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text('Terjadi Kesalahan:\n$_errorMessage', textAlign: TextAlign.center));
    }
    if (_peminjamanList.isEmpty) {
      return const Center(child: Text('Anda belum pernah meminjam buku.'));
    }
    return _buildPeminjamanListView();
  }

  Widget _buildPeminjamanListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _peminjamanList.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _peminjamanList.length) {
          return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
        }
        final peminjaman = _peminjamanList[index];
        final bool canBeReturned = peminjaman.status == '1' || peminjaman.status == '3';

        String statusText;
        Color statusColor;
        switch (peminjaman.status) {
          case '1': statusText = 'Dipinjam'; statusColor = Colors.orange; break;
          case '2': statusText = 'Dikembalikan'; statusColor = Colors.green; break;
          case '3': statusText = 'Terlambat'; statusColor = Colors.red; break;
          default: statusText = 'Tidak Diketahui'; statusColor = Colors.grey;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peminjaman.book.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Dipinjam pada: ${peminjaman.tanggalPinjam}'),
                const Divider(height: 20),
                
                // ==================== LOGIKA TAMPILAN TANGGAL ====================
                if (peminjaman.status == '2')
                  // Jika status sudah 'Dikembalikan'
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Dikembalikan pada: ${peminjaman.tanggalKembali}', // Menampilkan tanggal jatuh tempo
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  // Jika status masih 'Dipinjam' atau 'Terlambat'
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Batas Kembali: ${peminjaman.tanggalKembali}',
                      style: TextStyle(color: peminjaman.status == '3' ? Colors.red : Colors.black),
                    ),
                  ),

                // Tampilkan tombol hanya jika buku bisa dikembalikan
                if (canBeReturned)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Kembalikan Buku Ini'),
                        onPressed: () => _handleReturnBook(peminjaman.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget bantuan untuk membuat baris info yang rapi
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade700)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}