import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/screens/auth/login_screen.dart';
import 'package:perpus_app/screens/book/member_book_list_screen.dart';
import 'package:perpus_app/screens/peminjaman/my_peminjaman_list_screen.dart'; // Pastikan import ini ada

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final ApiService _apiService = ApiService();
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await _apiService.getUserName();
    if (mounted) {
      setState(() {
        _userName = name;
      });
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KARTU SAMBUTAN
            Card(
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
            ),
            const SizedBox(height: 24),

            // TOMBOL LIHAT DAFTAR BUKU
            ElevatedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text('Lihat Daftar Buku'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18)
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MemberBookListScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // TOMBOL RIWAYAT PEMINJAMAN SAYA
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Riwayat Peminjaman Saya'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.teal, // Warna berbeda agar mudah dikenali
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyPeminjamanListScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}