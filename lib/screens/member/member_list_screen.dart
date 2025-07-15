import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/user_response.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final ApiService _apiService = ApiService();
  
  List<User> _members = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _loadMembers(page: _currentPage);
  }

  Future<void> _loadMembers({required int page}) async {
    setState(() { _isLoading = true; });
    try {
      final UserResponse response = await _apiService.getMembers(page: page);
      setState(() {
        _members = response.users;
        _currentPage = response.currentPage;
        _lastPage = response.lastPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _nextPage() {
    if (_currentPage < _lastPage) {
      _loadMembers(page: _currentPage + 1);
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      _loadMembers(page: _currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Member'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildMemberListView()),
                _buildPaginationControls(),
              ],
            ),
    );
  }

  Widget _buildMemberListView() {
    if (_members.isEmpty) {
      return const Center(child: Text('Tidak ada member ditemukan.'));
    }
    return RefreshIndicator(
      onRefresh: () => _loadMembers(page: 1),
      child: ListView.builder(
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey.shade100,
                child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
              ),
              title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(member.email),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
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