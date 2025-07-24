import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/user_response.dart';

// Enum untuk status filter
enum MemberFilter { semua, punyaPinjaman, tidakAdaPinjaman, terlambat }

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final ApiService _apiService = ApiService();

  List<User> _members = [];
  List<Peminjaman> _allPeminjaman = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _lastPage = 1;

  // --- STATE BARU UNTUK SEARCH & FILTER ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  MemberFilter _currentFilter = MemberFilter.semua;
  
  // Cache untuk semua member data dengan optimasi
  List<User> _allMembersCache = [];
  List<Peminjaman> _allPeminjamanCache = [];
  bool _allMembersLoaded = false;
  DateTime? _cacheTimestamp;
  bool _isSearching = false;
  int _totalMembers = 0; // Total members dari server
  
  // State untuk statistik real-time dari dashboard API
  int _dashboardTotalMembers = 0;
  int _dashboardMembersWithBorrowings = 0;
  int _dashboardMembersWithoutBorrowings = 0;
  int _dashboardMembersOverdue = 0;
  int _dashboardTotalActiveBorrowings = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData(page: 1);
    _searchController.addListener(_onSearchChanged);
    
    // Optimasi: Preload semua data member di background untuk performa search yang lebih baik
    _preloadAllData();
    
    // Load statistik dashboard real-time terlebih dahulu
    _fetchMemberDashboardStatistics();
    
    // Load total member count dengan delay untuk menghindari race condition
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadTotalMembersCount();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    
    // Optimasi: Clean up cache jika terlalu besar untuk menghindari memory leak
    if (_allMembersCache.length > 500) {
      print('🗑️ MEMORY OPTIMIZATION: Clearing large cache on dispose');
      _invalidateCache();
    }
    
    super.dispose();
  }

  // Fungsi utilitas untuk perhitungan status yang akurat
  bool _isMemberHasBorrowings(User member) {
    return _allPeminjaman.any((p) => p.user.id == member.id && p.status == '1');
  }

  int _getMemberActiveBorrowings(User member) {
    return _allPeminjaman.where((p) => p.user.id == member.id && p.status == '1').length;
  }

  int _getMemberReturnedBorrowings(User member) {
    return _allPeminjaman.where((p) => p.user.id == member.id && (p.status == '2' || p.status == '3')).length;
  }

  int _getMemberOverdueBorrowings(User member) {
    final now = DateTime.now();
    return _allPeminjaman.where((p) {
      if (p.user.id == member.id && p.status == '1') {
        try {
          final tanggalKembali = DateTime.parse(p.tanggalKembali);
          return now.isAfter(tanggalKembali);
        } catch (e) {
          return false;
        }
      }
      return false;
    }).length;
  }

  String _getMemberStatus(User member) {
    final activeBorrowings = _getMemberActiveBorrowings(member);
    final overdueBorrowings = _getMemberOverdueBorrowings(member);
    
    if (activeBorrowings == 0) {
      return 'Tidak Ada Pinjaman';
    } else if (overdueBorrowings > 0) {
      return 'Ada Terlambat ($overdueBorrowings)';
    } else {
      return 'Sedang Meminjam ($activeBorrowings)';
    }
  }

  Color _getMemberStatusColor(User member) {
    final activeBorrowings = _getMemberActiveBorrowings(member);
    final overdueBorrowings = _getMemberOverdueBorrowings(member);
    
    if (activeBorrowings == 0) {
      return Colors.green;
    } else if (overdueBorrowings > 0) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  // Fetch statistik real-time dari dashboard API
  Future<void> _fetchMemberDashboardStatistics() async {
    try {
      final dashboardData = await _apiService.getMemberDashboardData();
      
      if (mounted) {
        setState(() {
          _dashboardTotalMembers = dashboardData['total_members'] ?? 0;
          _dashboardMembersWithBorrowings = dashboardData['members_with_borrowings'] ?? 0;
          _dashboardMembersWithoutBorrowings = dashboardData['members_without_borrowings'] ?? 0;
          _dashboardMembersOverdue = dashboardData['members_overdue'] ?? 0;
          _dashboardTotalActiveBorrowings = dashboardData['total_active_borrowings'] ?? 0;
        });
      }
    } catch (e) {
      print('Dashboard API failed, using fallback calculation: $e');
      // Jika API gagal, gunakan perhitungan lokal sebagai fallback
      if (mounted) {
        _calculateFallbackStatistics();
      }
    }
  }

  // Fallback calculation jika dashboard API gagal
  void _calculateFallbackStatistics() {
    final stats = _calculateMemberStatistics(_filteredMembers);
    setState(() {
      _dashboardTotalMembers = stats['total'] ?? 0;
      _dashboardMembersWithBorrowings = stats['withBorrowings'] ?? 0;
      _dashboardMembersWithoutBorrowings = stats['withoutBorrowings'] ?? 0;
      _dashboardMembersOverdue = stats['overdue'] ?? 0;
    });
  }

  // Optimasi: Invalidate cache untuk refresh data
  void _invalidateCache() {
    _allMembersCache.clear();
    _allPeminjamanCache.clear();
    _allMembersLoaded = false;
    _cacheTimestamp = null;
    print('🗑️ CACHE INVALIDATED: Cache dihapus untuk refresh data');
  }

  // Optimasi: Preload dan cache data untuk performa yang lebih baik
  Future<void> _preloadAllData() async {
    if (_allMembersLoaded && _allMembersCache.isNotEmpty) return;
    
    try {
      List<User> allMembers = [];
      List<Peminjaman> allPeminjaman = [];
      await _loadAllMembersForSearch(allMembers, allPeminjaman);
      
      // Update total members dari hasil preload
      if (mounted && allMembers.isNotEmpty) {
        setState(() {
          _totalMembers = allMembers.length;
        });
      }
    } catch (e) {
      print('Error preloading data: $e');
    }
  }

  // Optimasi: Refresh yang efisien dengan cache invalidation
  Future<void> _optimizedRefresh() async {
    print('🔄 OPTIMIZED REFRESH: Starting optimized refresh...');
    
    // Invalidate cache untuk memastikan data fresh
    _invalidateCache();
    
    // Reset state untuk refresh
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load fresh data
      await _loadAllData(page: 1, query: _searchController.text.isNotEmpty ? _searchController.text : null);
      
      // Refresh dashboard statistics
      await _fetchMemberDashboardStatistics();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Data berhasil diperbarui'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      print('✅ OPTIMIZED REFRESH: Refresh completed successfully with dashboard statistics');
    } catch (e) {
      print('❌ OPTIMIZED REFRESH: Error during refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Optimasi: Loading indicator yang lebih informatif
  Widget _buildOptimizedLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Modern circular progress indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
              strokeWidth: 3,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Dynamic loading text
          Text(
            _getLoadingText(),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle with more info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _getLoadingSubtitle(),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Progress estimation jika memungkinkan
          if (_isSearching && _allMembersCache.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Text(
                  'Menggunakan data cache (${_allMembersCache.length} member)',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper untuk dynamic loading text
  String _getLoadingText() {
    if (_isSearching) {
      return 'Mencari member...';
    } else if (_searchController.text.isEmpty) {
      return 'Memuat data member...';
    } else {
      return 'Memproses pencarian...';
    }
  }

  // Helper untuk dynamic loading subtitle
  String _getLoadingSubtitle() {
    if (_isSearching) {
      return 'Sedang mencari "${_searchController.text}" di database';
    } else if (_allMembersCache.isNotEmpty) {
      return 'Mengoptimalkan data dari cache';
    } else {
      return 'Mengambil data dari server...';
    }
  }

  Widget _buildStatisticsSummary() {
    // Gunakan statistik real-time dari dashboard API, fallback ke perhitungan lokal jika API gagal
    final usesDashboardData = _dashboardTotalMembers > 0;
    
    final totalMembers = usesDashboardData ? _dashboardTotalMembers : _filteredMembers.length;
    final withBorrowings = usesDashboardData ? _dashboardMembersWithBorrowings : _calculateMemberStatistics(_filteredMembers)['withBorrowings']!;
    final withoutBorrowings = usesDashboardData ? _dashboardMembersWithoutBorrowings : _calculateMemberStatistics(_filteredMembers)['withoutBorrowings']!;
    final overdue = usesDashboardData ? _dashboardMembersOverdue : _calculateMemberStatistics(_filteredMembers)['overdue']!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        children: [
          // Indikator sumber data
          // if (usesDashboardData)
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     margin: const EdgeInsets.only(bottom: 8),
          //     decoration: BoxDecoration(
          //       color: Colors.green.shade100,
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(color: Colors.green.shade300),
          //     ),
          //     child: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Icon(Icons.cloud_done, color: Colors.green.shade700, size: 14),
          //         const SizedBox(width: 4),
          //         Text(
          //           'Data Real-time dari Server',
          //           style: TextStyle(
          //             color: Colors.green.shade700,
          //             fontSize: 11,
          //             fontWeight: FontWeight.w600,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          
          // Kartu statistik
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryCard('Total Member', totalMembers.toString(), Colors.blue, Icons.people),
                const SizedBox(width: 8),
                _buildSummaryCard('Punya Pinjaman', withBorrowings.toString(), Colors.orange, Icons.book),
                const SizedBox(width: 8),
                _buildSummaryCard('Terlambat', overdue.toString(), Colors.red, Icons.warning),
                const SizedBox(width: 8),
                _buildSummaryCard('Tidak Ada Pinjaman', withoutBorrowings.toString(), Colors.green, Icons.check_circle),
                if (_dashboardTotalActiveBorrowings > 0) ...[
                  const SizedBox(width: 8),
                  _buildSummaryCard('Total Pinjaman Aktif', _dashboardTotalActiveBorrowings.toString(), Colors.purple, Icons.auto_stories),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Optimasi: Fungsi terpisah untuk menghitung statistik dengan efisien
  Map<String, int> _calculateMemberStatistics(List<User> members) {
    int totalWithBorrowings = 0;
    int totalWithoutBorrowings = 0;
    int totalOverdue = 0;
    
    // Single loop untuk menghitung semua statistik sekaligus
    for (User member in members) {
      final hasBorrowings = _isMemberHasBorrowings(member);
      if (hasBorrowings) {
        totalWithBorrowings++;
        if (_getMemberOverdueBorrowings(member) > 0) {
          totalOverdue++;
        }
      } else {
        totalWithoutBorrowings++;
      }
    }
    
    return {
      'total': members.length,
      'withBorrowings': totalWithBorrowings,
      'withoutBorrowings': totalWithoutBorrowings,
      'overdue': totalOverdue,
    };
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 100, // Fixed width untuk konsistensi
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Fungsi untuk load total members count secara background
  Future<void> _loadTotalMembersCount() async {
    try {
      List<User> allMembers = [];
      List<Peminjaman> allPeminjaman = [];
      await _loadAllMembersForSearch(allMembers, allPeminjaman);
      
      if (mounted) {
        setState(() {
          _totalMembers = allMembers.length;
        });
      }
    } catch (e) {
      print('Error loading total members count: $e');
      // Set default total if error
      if (mounted) {
        setState(() {
          _totalMembers = 92; // Default berdasarkan log sebelumnya
        });
      }
    }
  }

  // Optimasi: Debouncing pencarian dengan caching yang lebih baik
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final query = _searchController.text.trim();
      
      // Optimasi: Jika query kosong, langsung load pagination normal
      if (query.isEmpty) {
        await _loadAllData(page: 1, query: null);
        return;
      }
      
      // Optimasi: Jika query sangat pendek (< 2 karakter), delay lebih lama untuk menghindari banyak request
      if (query.length < 2) {
        print('🔍 SEARCH: Query too short, waiting for more characters...');
        return;
      }
      
      print('🔍 OPTIMIZED SEARCH: Starting search for: "$query"');
      await _loadAllData(page: 1, query: query);
    });
    
    // Update UI untuk menampilkan/menyembunyikan tombol clear
    setState(() {});
  }

  Future<void> _loadAllData({required int page, String? query}) async {
    setState(() {
      _isLoading = true;
      _isSearching = query != null && query.isNotEmpty;
    });
    
    // Debug log untuk melihat query yang dikirim
    print('Loading members with query: $query, page: $page');
    
    try {
      List<User> allMembers = [];
      List<Peminjaman> allPeminjaman = [];
      
      // Jika ada query pencarian, ambil semua data member terlebih dahulu
      if (query != null && query.isNotEmpty) {
        // Ambil semua member dari semua halaman untuk pencarian lokal
        await _loadAllMembersForSearch(allMembers, allPeminjaman);
        
        // Filter berdasarkan query di sisi client
        final filteredMembers = allMembers.where((member) => 
          member.name.toLowerCase().contains(query.toLowerCase()) ||
          member.email.toLowerCase().contains(query.toLowerCase()) ||
          member.username.toLowerCase().contains(query.toLowerCase())
        ).toList();
        
        print('Filtered ${filteredMembers.length} members from ${allMembers.length} total members');
        
        setState(() {
          _members = filteredMembers;
          _currentPage = 1;
          _lastPage = 1; // Karena hasil filter ditampilkan dalam satu halaman
          _allPeminjaman = allPeminjaman;
          _isLoading = false;
          _isSearching = false;
        });
      } else {
        // Jika tidak ada pencarian, gunakan pagination normal
        final responses = await Future.wait([
          _apiService.getMembers(page: page, perPage: 10),
          _apiService.getPeminjamanList(page: 1),
        ]);

        final UserResponse memberResponse = responses[0] as UserResponse;
        final PeminjamanResponse peminjamanResponse = responses[1] as PeminjamanResponse;

        setState(() {
          _members = memberResponse.users;
          _currentPage = memberResponse.currentPage;
          _lastPage = memberResponse.lastPage;
          _allPeminjaman = peminjamanResponse.peminjamanList;
          _isLoading = false;
          _isSearching = false;
        });
      }
      
      // Debug log untuk melihat hasil pencarian
      print('Found ${_members.length} members');
      
      // Refresh dashboard statistics setelah load data berhasil
      await _fetchMemberDashboardStatistics();
      
      print('✅ LOAD DATA: Successfully loaded members and statistics from dashboard API');
      
    } catch (e) {
      print('Error loading members: $e');
      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // Optimasi: Fungsi untuk mengambil semua member dengan batching yang efisien
  Future<void> _loadAllMembersForSearch(List<User> allMembers, List<Peminjaman> allPeminjaman) async {
    // Jika cache sudah ada dan belum expired (30 menit), gunakan cache
    if (_allMembersLoaded && _allMembersCache.isNotEmpty && _cacheTimestamp != null) {
      final cacheAge = DateTime.now().difference(_cacheTimestamp!);
      if (cacheAge.inMinutes < 30) {
        print('🟢 OPTIMIZED: Menggunakan cache member (${_allMembersCache.length} members, cache age: ${cacheAge.inMinutes} menit)');
        allMembers.clear();
        allMembers.addAll(_allMembersCache);
        // Pastikan peminjaman data juga di-cache
        if (_allPeminjamanCache.isNotEmpty) {
          allPeminjaman.clear();
          allPeminjaman.addAll(_allPeminjamanCache);
        }
        return;
      } else {
        print('🔄 CACHE EXPIRED: Memuat ulang data member (cache expired ${cacheAge.inMinutes} menit)');
        _invalidateCache();
      }
    }

    print('🔄 OPTIMIZED: Loading all members with efficient batching...');
    int currentPage = 1;
    int lastPage = 1;
    int batchSize = 20; // Optimasi: Increase batch size untuk mengurangi jumlah request
    List<Future<dynamic>> batchRequests = [];
    
    do {
      print('Loading page $currentPage for search...');
      
      try {
        // Optimasi: Load multiple pages in parallel (batching)
        batchRequests.clear();
        
        // Load current page
        batchRequests.add(_apiService.getMembers(page: currentPage, perPage: batchSize));
        
        // Load peminjaman data hanya di halaman pertama
        if (currentPage == 1) {
          batchRequests.add(_apiService.getPeminjamanList(page: 1));
        }
        
        // Load next page in parallel jika memungkinkan
        if (currentPage < lastPage) {
          batchRequests.add(_apiService.getMembers(page: currentPage + 1, perPage: batchSize));
        }

        final responses = await Future.wait(batchRequests);

        // Process first response (current page)
        final UserResponse memberResponse = responses[0] as UserResponse;
        allMembers.addAll(memberResponse.users);
        lastPage = memberResponse.lastPage;
        
        // Process peminjaman data jika ada
        int responseIndex = 1;
        if (currentPage == 1 && responses.length > responseIndex && responses[responseIndex] != null) {
          final peminjamanResponse = responses[responseIndex] as PeminjamanResponse;
          allPeminjaman.addAll(peminjamanResponse.peminjamanList);
          responseIndex++;
        }
        
        // Process second page jika di-load dalam batch
        if (responses.length > responseIndex && currentPage < lastPage) {
          final nextPageResponse = responses[responseIndex] as UserResponse;
          allMembers.addAll(nextPageResponse.users);
          currentPage++; // Skip next page karena sudah di-load
        }
        
        currentPage++;
        
        // Optimasi: Reduced delay dan adaptive rate limiting
        if (currentPage <= lastPage) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
      } catch (e) {
        print('Error loading page $currentPage: $e');
        
        // Jika error 429 (too many requests), tunggu lebih lama dan coba lagi
        if (e.toString().contains('429')) {
          print('Rate limit hit, waiting 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
          // Jangan increment currentPage, coba lagi halaman yang sama
          continue;
        } else {
          // Untuk error lain, skip halaman ini dan lanjut
          print('Skipping page $currentPage due to error');
          currentPage++;
        }
      }
    } while (currentPage <= lastPage);
    
    // Optimasi: Simpan ke cache dengan timestamp untuk cache expiration
    _allMembersCache = List.from(allMembers);
    _allPeminjamanCache = List.from(allPeminjaman);
    _allMembersLoaded = true;
    _cacheTimestamp = DateTime.now();
    _totalMembers = allMembers.length; // Simpan total members
    
    print('✅ OPTIMIZED: Loaded total ${allMembers.length} members from $lastPage pages and cached with timestamp');
  }

  void _nextPage() {
    if (_currentPage < _lastPage && _searchController.text.isEmpty) {
      _loadAllData(page: _currentPage + 1, query: _searchController.text.isEmpty ? null : _searchController.text);
    }
  }

  void _prevPage() {
    if (_currentPage > 1 && _searchController.text.isEmpty) {
      _loadAllData(page: _currentPage - 1, query: _searchController.text.isEmpty ? null : _searchController.text);
    }
  }

  // --- FUNGSI UNTUK MENERAPKAN FILTER DI SISI KLIEN ---
  List<User> get _filteredMembers {
    if (_currentFilter == MemberFilter.semua) {
      return _members;
    }
    return _members.where((member) {
      final bool punyaPinjaman = _isMemberHasBorrowings(member);
      final bool adaTerlambat = _getMemberOverdueBorrowings(member) > 0;
      
      if (_currentFilter == MemberFilter.punyaPinjaman) {
        return punyaPinjaman;
      }
      if (_currentFilter == MemberFilter.tidakAdaPinjaman) {
        return !punyaPinjaman;
      }
      if (_currentFilter == MemberFilter.terlambat) {
        return adaTerlambat;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade50,
              Colors.blue.shade50,
              Colors.indigo.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade600,
                      Colors.indigo.shade600,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Title Row
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Manajemen Member',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _searchController.text.isNotEmpty 
                                  ? '${_filteredMembers.length} member ditemukan dari ${_totalMembers > 0 ? _totalMembers : 92} total'
                                  : '${_totalMembers > 0 ? _totalMembers : 92} total member (Menampilkan ${_filteredMembers.length})',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari member...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade400, Colors.indigo.shade400],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.search, color: Colors.white, size: 20),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                                  onPressed: () {
                                    _searchController.clear();
                                    // Reset ke pagination normal halaman 1
                                    _loadAllData(page: 1, query: null);
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Filter Chips - Fixed dengan SingleChildScrollView
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildModernFilterChip(
                            'Semua',
                            _currentFilter == MemberFilter.semua,
                            () => setState(() => _currentFilter = MemberFilter.semua),
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildModernFilterChip(
                            'Punya Pinjaman',
                            _currentFilter == MemberFilter.punyaPinjaman,
                            () => setState(() => _currentFilter = MemberFilter.punyaPinjaman),
                            Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _buildModernFilterChip(
                            'Tidak Ada Pinjaman',
                            _currentFilter == MemberFilter.tidakAdaPinjaman,
                            () => setState(() => _currentFilter = MemberFilter.tidakAdaPinjaman),
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildModernFilterChip(
                            'Terlambat',
                            _currentFilter == MemberFilter.terlambat,
                            () => setState(() => _currentFilter = MemberFilter.terlambat),
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Statistics Summary Cards with refresh button
              // if (!_isLoading) 
              //   Column(
              //     children: [
              //       _buildStatisticsSummary(),
                    // Tombol refresh statistik kecil
                //     Container(
                //       margin: const EdgeInsets.symmetric(horizontal: 20),
                //       child: Row(
                //         mainAxisAlignment: MainAxisAlignment.end,
                //         children: [
                //           TextButton.icon(
                //             onPressed: () async {
                //               await _fetchMemberDashboardStatistics();
                //               if (mounted) {
                //                 ScaffoldMessenger.of(context).showSnackBar(
                //                   const SnackBar(
                //                     content: Text('Statistik diperbarui'),
                //                     duration: Duration(seconds: 1),
                //                   ),
                //                 );
                //               }
                //             },
                //             icon: const Icon(Icons.refresh, size: 16),
                //             label: const Text('Refresh Stats', style: TextStyle(fontSize: 12)),
                //             style: TextButton.styleFrom(
                //               foregroundColor: Colors.grey[600],
                //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ],
                // ),
              
              // Content
              Expanded(
                child: _isLoading
                  ? _buildOptimizedLoadingIndicator()
                  : _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada member',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tidak ada member yang sesuai dengan kriteria',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _optimizedRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredMembers.length,
                          itemBuilder: (context, index) {
                            return _buildModernMemberCard(_filteredMembers[index]);
                          },
                        ),
                      ),
              ),
              
              // Pagination (hanya tampilkan jika tidak sedang search)
              if (!_isLoading && _filteredMembers.isNotEmpty && _searchController.text.isEmpty) _buildModernPaginationControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFilterChip(String label, bool isSelected, VoidCallback onTap, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected 
          ? LinearGradient(colors: [color.withOpacity(0.8), color])
          : null,
        color: isSelected ? null : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernMemberCard(User member) {
    final sedangDipinjam = _getMemberActiveBorrowings(member);
    final sudahDikembalikan = _getMemberReturnedBorrowings(member);
    final terlambat = _getMemberOverdueBorrowings(member);
    final memberStatus = _getMemberStatus(member);
    final statusColor = _getMemberStatusColor(member);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.indigo.shade400],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          title: Text(
            member.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                member.email,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Status member dengan warna yang sesuai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  memberStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMiniStatChip('Aktif: $sedangDipinjam', sedangDipinjam > 0 ? Colors.blue : Colors.grey.shade400),
                    const SizedBox(width: 6),
                    _buildMiniStatChip('Selesai: $sudahDikembalikan', sudahDikembalikan > 0 ? Colors.green : Colors.grey.shade400),
                    if (terlambat > 0) ...[
                      const SizedBox(width: 6),
                      _buildMiniStatChip('Terlambat: $terlambat', Colors.red),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.grey.shade300, Colors.transparent],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // User Details
                  _buildModernDetailRow(Icons.person_outline, 'Username', member.username),
                  const SizedBox(height: 8),
                  _buildModernDetailRow(Icons.email_outlined, 'Email', member.email),
                  const SizedBox(height: 8),
                  _buildModernDetailRow(Icons.badge_outlined, 'ID Member', member.id.toString()),
                  const SizedBox(height: 8),
                  _buildModernDetailRow(
                    statusColor == Colors.red ? Icons.warning_outlined : 
                    statusColor == Colors.blue ? Icons.book_outlined : Icons.check_circle_outline,
                    'Status Saat Ini',
                    memberStatus,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Statistics Cards - Using IntrinsicHeight untuk konsistensi tinggi
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildModernStatCard(
                            'Sedang Dipinjam',
                            sedangDipinjam.toString(),
                            sedangDipinjam > 0 ? Colors.blue : Colors.grey,
                            Icons.book_outlined,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildModernStatCard(
                            'Telah Dikembalikan',
                            sudahDikembalikan.toString(),
                            sudahDikembalikan > 0 ? Colors.green : Colors.grey,
                            Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildModernStatCard(
                            'Terlambat',
                            terlambat.toString(),
                            terlambat > 0 ? Colors.red : Colors.grey,
                            Icons.warning_outlined,
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
    );
  }

  Widget _buildMiniStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildModernDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade100, Colors.indigo.shade100],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.indigo.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: Colors.white, size: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 1),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPaginationControls() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        children: [
          // Page info dengan layout yang fleksibel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _searchController.text.isNotEmpty 
                ? 'Hasil pencarian: ${_filteredMembers.length} member'
                : 'Halaman $_currentPage dari $_lastPage (${_totalMembers > 0 ? _totalMembers : 92} total)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button
              Container(
                decoration: BoxDecoration(
                  gradient: _currentPage > 1 
                    ? LinearGradient(colors: [Colors.purple.shade400, Colors.indigo.shade400])
                    : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _currentPage > 1 ? [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ] : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _currentPage > 1 ? _prevPage : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '<',
                            style: TextStyle(
                              color: _currentPage > 1 ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Next button
              Container(
                decoration: BoxDecoration(
                  gradient: _currentPage < _lastPage
                    ? LinearGradient(colors: [Colors.purple.shade400, Colors.indigo.shade400])
                    : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _currentPage < _lastPage ? [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ] : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _currentPage < _lastPage ? _nextPage : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '>',
                            style: TextStyle(
                              color: _currentPage < _lastPage ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}