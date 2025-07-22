import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';

class MyPeminjamanListScreen extends StatefulWidget {
  const MyPeminjamanListScreen({super.key});

  @override
  State<MyPeminjamanListScreen> createState() => _MyPeminjamanListScreenState();
}

class _MyPeminjamanListScreenState extends State<MyPeminjamanListScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Peminjaman> _peminjamanList = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    print("--- Membuka Halaman Riwayat Peminjaman Saya ---");
    _loadInitial();
    _scrollController.addListener(_onScroll);
    
    // Start animation
    Future.delayed(const Duration(milliseconds: 100), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  List<Peminjaman> get _filteredList {
    if (_selectedFilter == 'Semua') return _peminjamanList;
    if (_selectedFilter == 'Aktif') return _peminjamanList.where((p) => p.status == '1').toList();
    if (_selectedFilter == 'Terlambat') return _peminjamanList.where((p) => p.status == '3').toList();
    if (_selectedFilter == 'Selesai') return _peminjamanList.where((p) => p.status == '2').toList();
    return _peminjamanList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Modern App Bar
                      SliverAppBar(
                        expandedHeight: 120,
                        floating: true,
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        leading: Container(
                          margin: const EdgeInsets.only(left: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            'Riwayat Peminjaman',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black26,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Filter Chips
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: _buildFilterChips(),
                        ),
                      ),

                      // Content
                      _isLoading
                          ? _buildLoadingSliver()
                          : _errorMessage.isNotEmpty
                              ? _buildErrorSliver()
                              : _filteredList.isEmpty
                                  ? _buildEmptySliver()
                                  : _buildContentSliver(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Semua', 'Aktif', 'Terlambat', 'Selesai'];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Colors.white, Color(0xFFF8F9FF)],
                        )
                      : null,
                  color: isSelected ? null : Colors.white24,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF2D3748) : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat data...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi kesalahan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitial,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.history_outlined,
                size: 48,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat peminjaman',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Riwayat peminjaman Anda akan muncul di sini',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList.separated(
        itemCount: _filteredList.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= _filteredList.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          
          final peminjaman = _filteredList[index];
          return _buildModernPeminjamanCard(peminjaman);
        },
      ),
    );
  }

  Widget _buildModernPeminjamanCard(Peminjaman peminjaman) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8F9FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    peminjaman.book.judul,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusChip(peminjaman.status),
              ],
            ),
            const SizedBox(height: 16),
            
            // Book details
            Row(
              children: [
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Icon(
                      Icons.book,
                      color: Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penulis: ${peminjaman.book.pengarang}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Penerbit: ${peminjaman.book.penerbit}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tahun: ${peminjaman.book.tahun}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Dates info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tanggal Pinjam: ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        peminjaman.tanggalPinjam,
                        style: const TextStyle(
                          color: Color(0xFF2D3748),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Batas Kembali: ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        peminjaman.tanggalKembali,
                        style: TextStyle(
                          color: peminjaman.status == '3' ? Colors.red.shade600 : const Color(0xFF2D3748),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Return button for active loans
            if (peminjaman.status == '1') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleReturnBook(peminjaman.id),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Kembalikan Buku'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    String label;
    Color color;
    Color backgroundColor;
    IconData icon;

    switch (status) {
      case '1':
        label = 'AKTIF';
        color = Colors.blue.shade700;
        backgroundColor = Colors.blue.shade100;
        icon = Icons.schedule_outlined;
        break;
      case '2':
        label = 'SELESAI';
        color = Colors.green.shade700;
        backgroundColor = Colors.green.shade100;
        icon = Icons.check_circle_outline;
        break;
      case '3':
        label = 'TERLAMBAT';
        color = Colors.red.shade700;
        backgroundColor = Colors.red.shade100;
        icon = Icons.warning_amber_outlined;
        break;
      default:
        label = 'UNKNOWN';
        color = Colors.grey.shade700;
        backgroundColor = Colors.grey.shade100;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReturnBook(int peminjamanId) async {
    final String tanggalHariIni = 
        MaterialLocalizations.of(context).formatFullDate(DateTime.now());

    final bool? shouldReturn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.assignment_return_outlined,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Konfirmasi Pengembalian',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda akan mengembalikan buku ini. Apakah Anda yakin?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 20,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Pengembalian',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tanggalHariIni,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Ya, Kembalikan'),
          ),
        ],
      ),
    );

    if (shouldReturn == true) {
      await _processReturn(peminjamanId);
    }
  }

  Future<void> _processReturn(int peminjamanId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memproses pengembalian...'),
                ],
              ),
            ),
          ),
        ),
      );

      await _apiService.returnBook(peminjamanId);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buku berhasil dikembalikan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh data
      await _loadInitial();
      
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengembalikan buku: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
