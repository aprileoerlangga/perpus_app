import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/screens/auth/login_screen.dart';
import 'package:perpus_app/screens/book/member_book_list_screen.dart';
import 'package:perpus_app/screens/peminjaman/my_peminjaman_list_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final ApiService _apiService = ApiService();
  String? _userName;

  // --- STATE BARU UNTUK DATA DASHBOARD ---
  bool _isLoadingSummary = true;
  int _jumlahDipinjam = 0;
  int _jumlahTerlambat = 0;
  List<Peminjaman> _daftarPinjamanAktif = [];

  // --- STATE BARU ---
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // --- FUNGSI BARU UNTUK MENGAMBIL SEMUA DATA ---
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingSummary = true;
      _isLoadingCategories = true;
    });

    // Ambil nama user dan data ringkasan peminjaman secara bersamaan
    await Future.wait([
      _loadUserName(),
      _loadPeminjamanSummary(),
      _loadCategories(), // <-- Panggil fungsi baru
    ]);

    if (mounted) {
      setState(() {
        _isLoadingSummary = false;
        _isLoadingCategories = false;
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

      // Filter untuk mendapatkan buku yang masih aktif dipinjam (status 1 atau 3)
      final pinjamanAktif = allMyPeminjaman
          .where((p) => p.status == '1' || p.status == '3')
          .toList();
      
      // Hitung jumlah yang terlambat dari daftar pinjaman aktif
      final terlambat = pinjamanAktif.where((p) => p.status == '3').length;

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

  // --- FUNGSI BARU UNTUK MENGAMBIL KATEGORI ---
  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (e) {
      print("Gagal memuat kategori: $e");
    }
  }

  void _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Member'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Logout'),
        ],
      ),
      // --- TAMBAHKAN REFRESH INDICATOR ---
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // KARTU SAMBUTAN
            _buildWelcomeCard(),
            const SizedBox(height: 24),

            // --- BAGIAN RINGKASAN DATA ---
            _buildSummarySection(),
            const SizedBox(height: 24),

            // --- BAGIAN KATEGORI BARU ---
            _buildCategorySection(),
            const SizedBox(height: 24),

            // --- BAGIAN DAFTAR BUKU DIPINJAM ---
            _buildActiveLoansSection(),
            const SizedBox(height: 24),
            
            // --- BAGIAN MENU UTAMA ---
            _buildMainMenu(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BARU ---
  Widget _buildWelcomeCard() {
    return Card(
      color: Colors.indigo.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamat Datang,', style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            _userName == null
                ? const SizedBox(height: 28, width: 200, child: LinearProgressIndicator())
                : Text(_userName!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan Anda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _isLoadingSummary
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  Expanded(child: _buildSummaryCard('Buku Dipinjam', _jumlahDipinjam.toString(), Icons.book_outlined, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSummaryCard('Terlambat', _jumlahTerlambat.toString(), Icons.warning_amber_rounded, Colors.red)),
                ],
              ),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET UNTUK KATEGORI ---
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kategori Buku', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _isLoadingCategories
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ActionChip(
                      label: Text(category.name),
                      onPressed: () {
                        // ==================== PERUBAHAN DI SINI ====================
                        // Navigasi ke halaman daftar buku dan KIRIM SELURUH OBJEK KATEGORI
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MemberBookListScreen(
                            category: category, // <-- Kirim objek 'category'
                          ),
                        )).then((_) => _loadInitialData());
                        // ==========================================================
                      },
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildActiveLoansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sedang Dipinjam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _isLoadingSummary
            ? const Center(child: CircularProgressIndicator())
            : _daftarPinjamanAktif.isEmpty
                ? const Text('Anda tidak sedang meminjam buku.')
                : SizedBox(
                    height: 120, // Beri tinggi agar bisa di-scroll horizontal
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _daftarPinjamanAktif.length,
                      itemBuilder: (context, index) {
                        final peminjaman = _daftarPinjamanAktif[index];
                        return Container(
                          width: 250, // Lebar setiap kartu
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    peminjaman.book.judul,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Batas: ${peminjaman.tanggalKembali}',
                                    style: TextStyle(
                                      color: peminjaman.status == '3' ? Colors.red : Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildMainMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Menu Utama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMenuButton(
          icon: Icons.menu_book,
          label: 'Lihat Semua Buku',
          // --- TAMBAHKAN .then() UNTUK REFRESH ---
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const MemberBookListScreen(),
          )).then((_) => _loadInitialData()),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          icon: Icons.history,
          label: 'Riwayat Peminjaman Saya',
          // --- TAMBAHKAN .then() UNTUK REFRESH ---
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const MyPeminjamanListScreen(),
          )).then((_) => _loadInitialData()),
        ),
      ],
    );
  }
  
  Widget _buildMenuButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16),
        minimumSize: const Size(double.infinity, 50), // Buat tombol selebar layar
      ),
    );
  }
}