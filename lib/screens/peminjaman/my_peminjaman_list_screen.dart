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

  Future<void> _handleReturnBook(int peminjamanId) async {
    // Tampilkan dialog konfirmasi
    final bool? shouldReturn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pengembalian'),
        content: const Text('Anda yakin ingin mengembalikan buku ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ya, Kembalikan')),
        ],
      ),
    );

    if (shouldReturn == null || !shouldReturn) return;

    bool success = await _apiService.returnBook(peminjamanId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buku berhasil dikembalikan!')));
        _loadInitial(); // Muat ulang data untuk melihat perubahan status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengembalikan buku.')));
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
          child: ListTile(
            title: Text(peminjaman.book.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Batas Kembali: ${peminjaman.tanggalKembali ?? "-"}'),
            trailing: Chip(
              label: Text(statusText),
              backgroundColor: statusColor.withOpacity(0.2),
              labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
            onTap: canBeReturned ? () => _handleReturnBook(peminjaman.id) : null,
          ),
        );
      },
    );
  }
}