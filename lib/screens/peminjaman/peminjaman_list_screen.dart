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
      itemCount: _peminjamanList.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _peminjamanList.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final peminjaman = _peminjamanList[index];

        // Logika penerjemahan status (tetap sama)
        String statusText;
        Color statusColor;
        IconData statusIcon;

        switch (peminjaman.status) {
          case '1':
            statusText = 'Dipinjam';
            statusColor = Colors.blue;
            statusIcon = Icons.access_time_filled_rounded;
            break;
          case '2':
            statusText = 'Dikembalikan';
            statusColor = Colors.green;
            statusIcon = Icons.check_circle_rounded;
            break;
          case '3':
            statusText = 'Terlambat';
            statusColor = Colors.red;
            statusIcon = Icons.warning_rounded;
            break;
          default:
            statusText = 'Tidak Diketahui';
            statusColor = Colors.grey;
            statusIcon = Icons.help_outline_rounded;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Buku dan Peminjam (tetap sama)
                Text(
                  peminjaman.book.judul,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'oleh ${peminjaman.user.name}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const Divider(height: 20),

                // Informasi Detail Tanggal
                _buildInfoRow(Icons.calendar_today_outlined, 'Tgl. Pinjam', peminjaman.tanggalPinjam),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.event_busy_outlined, 'Batas Kembali', peminjaman.tanggalKembali),
                const SizedBox(height: 6),

                // ==================== TAMBAHAN KODE DI SINI ====================
                // Tampilkan tanggal pengembalian HANYA jika statusnya 'Dikembalikan'
                if (peminjaman.status == '2')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: _buildInfoRow(
                        Icons.event_available_outlined, 'Tgl. Kembali', peminjaman.tanggalPengembalian ?? '-'),
                  ),
                // ===============================================================

                const SizedBox(height: 6),

                // Tampilan Status Chip (tetap sama)
                Align(
                  alignment: Alignment.centerRight,
                  child: Chip(
                    avatar: Icon(statusIcon, color: Colors.white, size: 18),
                    label: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget bantuan (tetap sama)
  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey.shade700)),
        Expanded(
          child: Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}