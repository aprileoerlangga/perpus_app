import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/screens/auth/login_screen.dart';
import 'package:perpus_app/screens/book/member_book_list_screen.dart';
import 'package:perpus_app/screens/peminjaman/my_peminjaman_list_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final ApiService _apiService = ApiService();
  String? _userName;

  // --- STATE BARU UNTUK DATA DASHBOARD ---
  bool _isLoadingSummary = true;
  int _jumlahDipinjam = 0;
  int _jumlahTerlambat = 0;
  List<Peminjaman> _daftarPinjamanAktif = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _loadInitialData();
    
    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- FUNGSI BARU UNTUK MENGAMBIL SEMUA DATA ---
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingSummary = true;
    });

    // Ambil nama user dan data ringkasan peminjaman secara bersamaan
    await Future.wait([
      _loadUserName(),
      _loadPeminjamanSummary(),
    ]);

    if (mounted) {
      setState(() {
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _loadUserName() async {
    final name = await _apiService.getUserName();
    if (mounted) setState(() => _userName = name);
  }

  // --- FUNGSI BARU UNTUK MENGHITUNG RINGKASAN PEMINJAMAN ---
  Future<void> _loadPeminjamanSummary() async {
    try {
      final response = await _apiService.getMyPeminjamanList();
      final allMyPeminjaman = response.peminjamanList;

      // Filter untuk mendapatkan buku yang masih aktif dipinjam
      // Status 1 = dipinjam, status 2 dan 3 = sudah dikembalikan
      final pinjamanAktif = allMyPeminjaman
          .where((p) => p.status == '1')
          .toList();
      
      // Hitung jumlah yang terlambat dari daftar pinjaman aktif
      final now = DateTime.now();
      int terlambat = 0;
      
      for (var peminjaman in pinjamanAktif) {
        try {
          final dueDate = DateTime.parse(peminjaman.tanggalKembali);
          if (now.isAfter(dueDate)) {
            terlambat++;
          }
        } catch (e) {
          // Skip jika tidak bisa parse tanggal
          print("Error parsing date: ${peminjaman.tanggalKembali}");
        }
      }

      if (mounted) {
        setState(() {
          _daftarPinjamanAktif = pinjamanAktif;
          _jumlahDipinjam = pinjamanAktif.length;
          _jumlahTerlambat = terlambat;
        });
      }
    } catch (e) {
      // Handle error jika gagal memuat data
      print("Gagal memuat ringkasan: $e");
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Color(0xFF667eea),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Color(0xFF667eea),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
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
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
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
                    slivers: [
                      // Modern App Bar
                      SliverAppBar(
                        expandedHeight: 120,
                        floating: true,
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            'Dashboard Member',
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
                        actions: [
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF667eea),
                                  Color(0xFF764ba2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Logout',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
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
                      
                      // Content
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              // Welcome Card
                              _buildModernWelcomeCard(),
                              const SizedBox(height: 20),

                              // Summary Cards
                              _buildModernSummarySection(),
                              const SizedBox(height: 20),

                              // Active Loans
                              _buildModernActiveLoansSection(),
                              const SizedBox(height: 20),
                              
                              // Main Menu
                              _buildModernMainMenu(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
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

  // Modern Welcome Card dengan Personalized Content
  Widget _buildModernWelcomeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-1.0, -1.0),
          end: Alignment(1.0, 1.0),
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF8FAFF),
            Color(0xFFEFF1FF),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _userName == null
                          ? _buildShimmerName()
                          : Text(
                              _userName!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a202c),
                                letterSpacing: -0.5,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: const Color(0xFF667eea),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Jangan lupa kembalikan buku tepat waktu! 📚',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF667eea),
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildShimmerName() {
    return Container(
      height: 24,
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade100,
            Colors.grey.shade300,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi! ☀️';
    if (hour < 15) return 'Selamat Siang! 🌤️';
    if (hour < 18) return 'Selamat Sore! 🌅';
    return 'Selamat Malam! 🌙';
  }

  // Modern Summary Section
  Widget _buildModernSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Ringkasan Anda',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        _isLoadingSummary
            ? _buildLoadingCards()
            : Row(
                children: [
                  Expanded(
                    child: _buildModernSummaryCard(
                      'Buku Dipinjam',
                      _jumlahDipinjam.toString(),
                      Icons.library_books_rounded,
                      const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernSummaryCard(
                      'Terlambat',
                      _jumlahTerlambat.toString(),
                      Icons.schedule_rounded,
                      const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
                      ),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildLoadingCards() {
    return Row(
      children: [
        Expanded(child: _buildSkeletonCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildSkeletonCard()),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildModernSummaryCard(String title, String value, IconData icon, LinearGradient gradient) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          if (title == 'Buku Dipinjam' || title == 'Terlambat') {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MyPeminjamanListScreen(),
            )).then((_) => _loadInitialData());
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      if (title == 'Buku Dipinjam' && int.tryParse(value) != null)
                        _buildProgressBar(int.parse(value), 10), // Max 10 buku
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int current, int max) {
    final percentage = current / max;
    return Container(
      width: 60,
      height: 4,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percentage.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // Modern Active Loans Section
  Widget _buildModernActiveLoansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Sedang Dipinjam',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        _isLoadingSummary
            ? _buildActiveLoansLoading()
            : _daftarPinjamanAktif.isEmpty
                ? _buildEmptyActiveLoans()
                : SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _daftarPinjamanAktif.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final peminjaman = _daftarPinjamanAktif[index];
                        return _buildModernLoanCard(peminjaman);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildActiveLoansLoading() {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyActiveLoans() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.book_outlined,
            size: 48,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada buku yang sedang dipinjam',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoanCard(Peminjaman peminjaman) {
    // Gunakan logika yang sama dengan riwayat peminjaman
    final now = DateTime.now();
    bool isOverdue = false;
    int daysLeft = 0;
    
    try {
      final dueDate = DateTime.parse(peminjaman.tanggalKembali);
      daysLeft = dueDate.difference(now).inDays;
      isOverdue = now.isAfter(dueDate);
    } catch (e) {
      // Jika tidak bisa parse tanggal, gunakan fungsi lama sebagai fallback
      daysLeft = _calculateDaysLeft(peminjaman.tanggalKembali);
      isOverdue = daysLeft < 0;
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const MyPeminjamanListScreen(),
          )).then((_) => _loadInitialData());
        },
        child: Container(
          width: 300,
          height: 160, // Set fixed height to prevent overflow
          padding: const EdgeInsets.all(16), // Further reduced padding from 20 to 16
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isOverdue 
                  ? [const Color(0xFFFF6B6B), const Color(0xFFFF5252)]
                  : daysLeft <= 3
                      ? [const Color(0xFFFFB74D), const Color(0xFFFF9800)]
                      : [Colors.white, const Color(0xFFF8FAFF)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isOverdue 
                    ? Colors.red 
                    : daysLeft <= 3 
                        ? Colors.orange 
                        : const Color(0xFF667eea)).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
            border: !isOverdue && daysLeft > 3 ? Border.all(
              color: const Color(0xFF667eea).withOpacity(0.1),
              width: 1,
            ) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Use minimum size
            children: [
              // Header with icon and title
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8), // Further reduced padding
                      decoration: BoxDecoration(
                        color: (isOverdue || daysLeft <= 3) 
                            ? Colors.white.withOpacity(0.2) 
                            : const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10), // Further reduced radius
                        border: Border.all(
                          color: (isOverdue || daysLeft <= 3)
                              ? Colors.white.withOpacity(0.3)
                              : const Color(0xFF667eea).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getLoanStatusIcon(isOverdue, daysLeft),
                        color: (isOverdue || daysLeft <= 3) 
                            ? Colors.white 
                            : const Color(0xFF667eea),
                        size: 18, // Further reduced icon size
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // Minimize height
                        children: [
                          Text(
                            peminjaman.book.judul,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Further reduced font size
                              color: (isOverdue || daysLeft <= 3) 
                                  ? Colors.white 
                                  : const Color(0xFF1a202c),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2), // Reduced spacing
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 12, // Further reduced icon size
                                color: (isOverdue || daysLeft <= 3)
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  peminjaman.book.pengarang,
                                  style: TextStyle(
                                    color: (isOverdue || daysLeft <= 3)
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                    fontSize: 11, // Further reduced font size
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom section with date and status
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(10), // Further reduced padding
                  decoration: BoxDecoration(
                    color: (isOverdue || daysLeft <= 3)
                        ? Colors.white.withOpacity(0.15)
                        : const Color(0xFF667eea).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isOverdue || daysLeft <= 3)
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFF667eea).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date header - more compact
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12, // Further reduced icon size
                            color: (isOverdue || daysLeft <= 3)
                                ? Colors.white
                                : const Color(0xFF667eea),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Batas Kembali',
                            style: TextStyle(
                              color: (isOverdue || daysLeft <= 3)
                                  ? Colors.white70
                                  : const Color(0xFF667eea),
                              fontSize: 10, // Further reduced font size
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Date text
                      Text(
                        _formatDate(peminjaman.tanggalKembali),
                        style: TextStyle(
                          color: (isOverdue || daysLeft <= 3)
                              ? Colors.white
                              : const Color(0xFF1a202c),
                          fontSize: 11, // Further reduced font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      // Status chip
                      _buildStatusChip(isOverdue, daysLeft),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isOverdue, int daysLeft) {
    String label;
    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (isOverdue) {
      label = 'TERLAMBAT';
      backgroundColor = Colors.white.withOpacity(0.2);
      textColor = Colors.white;
      icon = Icons.warning_rounded;
    } else if (daysLeft <= 3) {
      label = 'SEGERA BERAKHIR';
      backgroundColor = Colors.white.withOpacity(0.2);
      textColor = Colors.white;
      icon = Icons.access_time_rounded;
    } else {
      label = 'AKTIF';
      backgroundColor = const Color(0xFF10B981).withOpacity(0.1);
      textColor = const Color(0xFF10B981);
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Further reduced padding
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12), // Further reduced radius
        border: Border.all(
          color: (isOverdue || daysLeft <= 3)
              ? Colors.white.withOpacity(0.3)
              : const Color(0xFF10B981).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: textColor), // Further reduced icon size
          const SizedBox(width: 3), // Further reduced spacing
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 8, // Further reduced font size
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLoanStatusIcon(bool isOverdue, int daysLeft) {
    if (isOverdue) return Icons.warning_rounded;
    if (daysLeft <= 3) return Icons.access_time_rounded;
    return Icons.menu_book_rounded;
  }

  int _calculateDaysLeft(String returnDate) {
    try {
      // Assuming the date format is 'dd-MM-yyyy' or 'yyyy-MM-dd'
      final parts = returnDate.split('-');
      DateTime date;
      
      if (parts[0].length == 4) {
        // Format: yyyy-MM-dd
        date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } else {
        // Format: dd-MM-yyyy
        date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      
      return date.difference(DateTime.now()).inDays;
    } catch (e) {
      return 7; // Default to 7 days if parsing fails
    }
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      const List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      // Jika gagal parse, coba dengan format lain
      try {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // Format: yyyy-MM-dd
            final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            const List<String> months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
              'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
            ];
            return '${date.day} ${months[date.month - 1]} ${date.year}';
          } else {
            // Format: dd-MM-yyyy
            final date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            const List<String> months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
              'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
            ];
            return '${date.day} ${months[date.month - 1]} ${date.year}';
          }
        }
      } catch (e2) {
        // Jika semua gagal, return string asli
        return dateString;
      }
      return dateString;
    }
  }

  // Modern Main Menu
  Widget _buildModernMainMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Menu Utama',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        _buildModernMenuButton(
          icon: Icons.library_books_rounded,
          label: 'Lihat Semua Buku',
          description: 'Jelajahi koleksi perpustakaan',
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MemberBookListScreen(),
            )).then((_) => _loadInitialData());
          },
        ),
        const SizedBox(height: 16),
        _buildModernMenuButton(
          icon: Icons.history_rounded,
          label: 'Riwayat Peminjaman',
          description: 'Lihat riwayat peminjaman Anda',
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MyPeminjamanListScreen(),
            )).then((_) => _loadInitialData());
          },
        ),
      ],
    );
  }

  Widget _buildModernMenuButton({
    required IconData icon,
    required String label,
    required String description,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}