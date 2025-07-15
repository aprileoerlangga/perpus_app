import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';

class PeminjamanListScreen extends StatefulWidget {
  const PeminjamanListScreen({super.key});

  @override
  State<PeminjamanListScreen> createState() => _PeminjamanListScreenState();
}

class _PeminjamanListScreenState extends State<PeminjamanListScreen> {
  // === State Management ===
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<Peminjaman> _peminjamanList = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  // === Data Loading Logic ===
  void _onScroll() {
    // Cek jika pengguna sudah scroll mendekati akhir daftar
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _peminjamanList = [];
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final PeminjamanResponse response = await _apiService.getPeminjamanList(page: _currentPage);
      setState(() {
        _peminjamanList = response.peminjamanList;
        _hasMore = response.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() { _isLoadingMore = true; });
    try {
      final PeminjamanResponse response = await _apiService.getPeminjamanList(page: _currentPage + 1);
      setState(() {
        _peminjamanList.addAll(response.peminjamanList);
        _currentPage++;
        _hasMore = response.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() { _isLoadingMore = false; });
    }
  }

  // === UI Building ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Peminjaman'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildPeminjamanListView(),
      ),
    );
  }

  Widget _buildPeminjamanListView() {
    if (_peminjamanList.isEmpty) {
      return const Center(child: Text('Tidak ada riwayat peminjaman.'));
    }
    return ListView.builder(
      controller: _scrollController,
      // Tambah 1 item untuk loading indicator di bawah
      itemCount: _peminjamanList.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Jika ini adalah item terakhir dan masih ada data, tampilkan loading
        if (index == _peminjamanList.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final peminjaman = _peminjamanList[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: peminjaman.status == 'dipinjam' ? Colors.orange.shade100 : Colors.green.shade100,
              child: Tooltip(
                message: peminjaman.status.toUpperCase(),
                child: Icon(
                  peminjaman.status == 'dipinjam' ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
                  color: peminjaman.status == 'dipinjam' ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
            ),
            title: Text(peminjaman.book.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Peminjam: ${peminjaman.user.name}\nTgl Pinjam: ${peminjaman.tanggalPinjam}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}