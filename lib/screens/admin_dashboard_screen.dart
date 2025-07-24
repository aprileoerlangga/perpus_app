import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/screens/auth/login_screen.dart';
import 'package:perpus_app/screens/book/book_list_screen.dart';
import 'package:perpus_app/screens/book/book_form_screen.dart';
import 'package:perpus_app/screens/category/category_form_screen.dart';
import 'package:perpus_app/screens/category/category_list_screen.dart';
import 'package:perpus_app/screens/member/member_list_screen.dart';
import 'package:perpus_app/screens/peminjaman/peminjaman_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String? _userName;
  bool _isLoading = true;

  // Statistik data - Gunakan data real-time dari dashboard API
  int _totalBooks = 0;
  int _totalStock = 0;
  int _totalCategories = 0;
  int _totalUsers = 0;
  int _aktivePeminjaman = 0;  // Peminjaman yang masih aktif
  int _totalReturned = 0;     // Total buku yang dikembalikan
  bool _isLoadingStats = true;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Auto-refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserData();
    _loadStatistics();
    _startAutoRefresh();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadStatistics();
        // Debug: Auto-refresh dashboard statistics
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final name = await _apiService.getUserName();
      setState(() {
        _userName = name;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoadingStats = true);
      
      print('🔄 Loading dashboard statistics...');
      final dashboardData = await _apiService.getDashboardData();
      print('📊 Received dashboard data: $dashboardData');

      if (mounted) {
        setState(() {
          // Data dari dashboard API dengan logging sesuai response struktur
          _totalBooks = dashboardData['total_books'] ?? 0;
          _totalStock = dashboardData['total_stock'] ?? 0;
          _totalCategories = dashboardData['total_categories'] ?? 0; // Fallback jika tidak ada di API
          _totalUsers = dashboardData['total_members'] ?? 0;
          _aktivePeminjaman = dashboardData['total_borrowed'] ?? 0;
          _totalReturned = dashboardData['total_returned'] ?? 0;
          _isLoadingStats = false;
        });
        
        print('✅ Statistics updated from API response:');
        print('   📚 Books: $_totalBooks (totalBuku)');
        print('   📦 Stock: $_totalStock (totalStok)');
        print('   🏷️  Categories: $_totalCategories (fallback)');
        print('   👥 Members: $_totalUsers (totalMember)');
        print('   📖 Borrowed: $_aktivePeminjaman (totalDipinjam)');
        print('   ✅ Returned: $_totalReturned (totalDikembalikan)');
      }
      
    } catch (e) {
      print('❌ Dashboard API failed: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Gagal memuat statistik: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: Colors.white,
              onPressed: () => _loadStatistics(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 16,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B6B),
                Color(0xFFFF8E53),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon dengan animasi
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Konfirmasi Logout',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Content
              Text(
                'Apakah Anda yakin ingin keluar?\nSesi Anda akan berakhir.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Logout Button
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFFF6B6B),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Logout',
                                style: TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                ),
                SizedBox(height: 16),
                Text(
                  'Sedang logout...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await _apiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dashboard Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (_userName != null)
              Text(
                'Selamat datang, $_userName',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Logout Button dengan desain modern - responsive
          Container(
            margin: EdgeInsets.only(right: isSmallScreen ? 8 : 16),
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? 80 : double.infinity,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _logout();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 16, 
                    vertical: 10
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      if (!isSmallScreen) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 16),
        ],
        toolbarHeight: 80,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Memuat dashboard...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeCard(),
                        const SizedBox(height: 24),
                        _buildStatisticsCards(constraints),
                        const SizedBox(height: 24),
                        _buildQuickActions(constraints),
                        const SizedBox(height: 24),
                        _buildMenuNavigation(),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallCard = constraints.maxWidth < 300;
          
          return isSmallCard 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.library_books,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '📚 Sistem Perpustakaan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola perpustakaan dengan mudah dan efisien',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📚 Sistem Perpustakaan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kelola perpustakaan dengan mudah dan efisien',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.library_books,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              );
        },
      ),
    );
  }

  Widget _buildStatisticsCards(BoxConstraints constraints) {
    final crossAxisCount = constraints.maxWidth < 600 ? 2 : 3;
    final childAspectRatio = constraints.maxWidth < 600 ? 1.15 : 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.analytics,
                color: Colors.indigo,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Statistik Perpustakaan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Refresh button
            IconButton(
              onPressed: () => _loadStatistics(),
              icon: Icon(
                Icons.refresh,
                color: Colors.indigo[600],
              ),
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _isLoadingStats
            ? _buildLoadingCards(crossAxisCount, childAspectRatio)
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildModernStatCard(
                    'Total Buku',
                    _totalBooks.toString(),
                    Icons.menu_book_rounded,
                    Colors.blue,
                    'koleksi perpustakaan',
                    0,
                  ),
                  _buildModernStatCard(
                    'Total Stok',
                    _totalStock.toString(),
                    Icons.inventory_rounded,
                    Colors.indigo,
                    'stok keseluruhan',
                    1,
                  ),
                  _buildModernStatCard(
                    'Total Member',
                    _totalUsers.toString(),
                    Icons.people_rounded,
                    Colors.orange,
                    'member aktif',
                    2,
                  ),
                  _buildModernStatCard(
                    'Sedang Dipinjam',
                    _aktivePeminjaman.toString(),
                    Icons.book_online_rounded,
                    Colors.purple,
                    'buku dipinjam',
                    3,
                  ),
                  _buildModernStatCard(
                    'Dikembalikan',
                    _totalReturned.toString(),
                    Icons.assignment_return_outlined,
                    Colors.teal,
                    'buku dikembalikan',
                    4,
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildLoadingCards(int crossAxisCount, double childAspectRatio) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: List.generate(5, (index) => _buildLoadingCard()),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, String subtitle, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: color.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -10,
                    left: -10,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Content with improved layout - FIXED VERSION
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallCard = constraints.maxWidth < 120;
                        final cardHeight = constraints.maxHeight;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon dan badge row - Fixed height allocation
                            SizedBox(
                              height: cardHeight * 0.25, // 25% untuk icon area
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isSmallCard ? 8 : 10),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: color,
                                      size: isSmallCard ? 16 : 20,
                                    ),
                                  ),
                                  if (!isSmallCard)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.trending_up,
                                        color: color,
                                        size: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Value area - Fixed height and centered - 35% dari tinggi card
                            SizedBox(
                              height: cardHeight * 0.35,
                              child: Center(
                                child: TweenAnimationBuilder<int>(
                                  duration: Duration(milliseconds: 1500 + (index * 200)),
                                  tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                                  builder: (context, animatedValue, child) {
                                    return FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        animatedValue.toString(),
                                        style: TextStyle(
                                          fontSize: isSmallCard ? 24 : 32,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                          height: 1.0,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Text area - Expanded to fill remaining space - 40% untuk labels
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Title dengan auto-resize dan better layout
                                  Flexible(
                                    flex: 2, // Title mendapat ruang lebih besar
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: isSmallCard ? 12 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 2),
                                  
                                  // Subtitle dengan auto-resize
                                  Flexible(
                                    flex: 1, // Subtitle mendapat ruang lebih kecil
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: isSmallCard ? 9 : 11,
                                          color: Colors.grey[600],
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BoxConstraints constraints) {
    final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
    final childAspectRatio = constraints.maxWidth < 600 ? 1.4 : 1.2;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.flash_on_rounded,
                color: Colors.amber[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Aksi Cepat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _buildModernActionCard(
              'Tambah Buku',
              'Tambahkan buku baru ke koleksi',
              Icons.add_box_rounded,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookFormScreen()),
              ),
              0,
            ),
            _buildModernActionCard(
              'Tambah Kategori',
              'Buat kategori buku baru',
              Icons.create_new_folder_rounded,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
              ),
              1,
            ),
            _buildModernActionCard(
              'Kelola Buku',
              'Lihat dan edit semua buku',
              Icons.library_books_rounded,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookListScreen()),
              ),
              2,
            ),
            _buildModernActionCard(
              'Lihat Peminjaman',
              'Monitor transaksi peminjaman',
              Icons.assignment_turned_in_rounded,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PeminjamanListScreen()),
              ),
              3,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernActionCard(String title, String description, IconData icon, Color color, VoidCallback onTap, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 150)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation)),
          child: Opacity(
            opacity: animation,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(
                    color: color.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      // Background decoration
                      Positioned(
                        top: -15,
                        right: -15,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isSmallCard = constraints.maxWidth < 140;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: color,
                                    size: isSmallCard ? 18 : 22,
                                  ),
                                ),
                                const Spacer(),
                                // Title
                                Flexible(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: isSmallCard ? 13 : 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Description
                                Flexible(
                                  child: Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: isSmallCard ? 10 : 12,
                                      color: Colors.grey[600],
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuNavigation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: Colors.indigo,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Menu Navigasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildMenuTile(
                'Kelola Buku',
                'Tambah, edit, dan hapus buku',
                Icons.library_books_rounded,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookListScreen()),
                ),
              ),
              _buildMenuTile(
                'Kelola Kategori',
                'Atur kategori buku',
                Icons.category_rounded,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryListScreen()),
                ),
              ),
              _buildMenuTile(
                'Kelola Member',
                'Manajemen data member',
                Icons.people_rounded,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemberListScreen()),
                ),
              ),
              _buildMenuTile(
                'Transaksi Peminjaman',
                'Monitor peminjaman dan pengembalian',
                Icons.swap_horiz_rounded,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PeminjamanListScreen()),
                ),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.grey[400],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: Colors.grey[200],
            indent: 56,
          ),
      ],
    );
  }
}