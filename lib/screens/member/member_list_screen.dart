import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/user_response.dart';

// Enum untuk status filter
enum MemberFilter { semua, punyaPinjaman, tidakAdaPinjaman }

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

  @override
  void initState() {
    super.initState();
    _loadAllData(page: 1);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- FUNGSI UNTUK DEBOUNCING PENCARIAN (SAMA DENGAN BUKU & CATEGORY) ---
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // Reset ke halaman 1 setiap kali search berubah
      final query = _searchController.text.trim();
      await _loadAllData(page: 1, query: query.isEmpty ? null : query);
    });
  }

  Future<void> _loadAllData({required int page, String? query}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final responses = await Future.wait([
        _apiService.getMembers(page: page, query: (query ?? '').isEmpty ? null : query),
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
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _lastPage) {
      _loadAllData(page: _currentPage + 1, query: _searchController.text);
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      _loadAllData(page: _currentPage - 1, query: _searchController.text);
    }
  }

  // --- FUNGSI UNTUK MENERAPKAN FILTER DI SISI KLIEN ---
  List<User> get _filteredMembers {
    if (_currentFilter == MemberFilter.semua) {
      return _members;
    }
    return _members.where((member) {
      final bool punyaPinjaman = _allPeminjaman.any((p) => p.user.id == member.id && (p.status == '1' || p.status == '3'));
      if (_currentFilter == MemberFilter.punyaPinjaman) {
        return punyaPinjaman;
      }
      if (_currentFilter == MemberFilter.tidakAdaPinjaman) {
        return !punyaPinjaman;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari member...',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 0),
            child: Wrap(
              spacing: 8.0,
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: _currentFilter == MemberFilter.semua,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentFilter = MemberFilter.semua);
                  },
                ),
                FilterChip(
                  label: const Text('Punya Pinjaman Aktif'),
                  selected: _currentFilter == MemberFilter.punyaPinjaman,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentFilter = MemberFilter.punyaPinjaman);
                  },
                ),
                FilterChip(
                  label: const Text('Tidak Ada Pinjaman'),
                  selected: _currentFilter == MemberFilter.tidakAdaPinjaman,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentFilter = MemberFilter.tidakAdaPinjaman);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMemberListView(),
          ),
          if (!_isLoading) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildMemberListView() {
    final List<User> membersToDisplay = _filteredMembers;

    if (membersToDisplay.isEmpty) {
      return Center(child: Text('Tidak ada member yang cocok dengan kriteria.'));
    }
    return RefreshIndicator(
      onRefresh: () => _loadAllData(page: 1, query: _searchController.text),
      child: ListView.builder(
        itemCount: membersToDisplay.length,
        itemBuilder: (context, index) {
          final member = membersToDisplay[index];

          final pinjamanMember = _allPeminjaman.where((p) => p.user.id == member.id).toList();
          final sedangDipinjam = pinjamanMember.where((p) => p.status == '1' || p.status == '3').length;
          final sudahDikembalikan = pinjamanMember.where((p) => p.status == '2').length;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade100,
                child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              ),
              title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(member.email),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Divider(),
                      _buildDetailRow(Icons.person_outline, 'Username', member.username),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard('Sedang Dipinjam', sedangDipinjam.toString(), Colors.blue),
                          const SizedBox(width: 12),
                          _buildStatCard('Telah Dikembalikan', sudahDikembalikan.toString(), Colors.green),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Text('$label:', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.end),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _currentPage == 1 ? null : _prevPage,
            child: const Row(children: [Icon(Icons.chevron_left), Text('Prev')]),
          ),
          Text('Halaman $_currentPage dari $_lastPage'),
          ElevatedButton(
            onPressed: _currentPage == _lastPage ? null : _nextPage,
            child: const Row(children: [Text('Next'), Icon(Icons.chevron_right)]),
          ),
        ],
      ),
    );
  }
}