import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart'; // <-- Pastikan import ini ada
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/screens/category/category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final ApiService _apiService = ApiService();

  List<Category> _allCategories = [];
  List<Book> _allBooks = [];
  List<Category> _pagedCategories = [];

  bool _isLoading = true;
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(_filterAndPaginate);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAllData() async {
    setState(() { _isLoading = true; });
    try {
      final responses = await Future.wait([
        _apiService.getCategories(),
        // --- PERBAIKAN 1: HAPUS PARAMETER 'limit' ---
        _apiService.getBooks(page: 1), 
      ]);

      final List<Category> categories = responses[0] as List<Category>;
      // --- PERBAIKAN 2: TAMBAHKAN 'as BookResponse' ---
      final BookResponse bookResponse = responses[1] as BookResponse;

      setState(() {
        _allCategories = categories;
        _allBooks = bookResponse.books;
        _filterAndPaginate();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${e.toString()}')),
        );
      }
    }
  }

  void _filterAndPaginate() {
    final query = _searchController.text.toLowerCase();
    List<Category> filtered;

    if (query.isNotEmpty) {
      filtered = _allCategories.where((cat) => cat.name.toLowerCase().contains(query)).toList();
    } else {
      filtered = _allCategories;
    }

    _totalPages = (filtered.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > filtered.length) {
      endIndex = filtered.length;
    }

    setState(() {
      _pagedCategories = filtered.getRange(startIndex, endIndex).toList();
    });
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() { _currentPage++; });
      _filterAndPaginate();
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      setState(() { _currentPage--; });
      _filterAndPaginate();
    }
  }

  void _navigateToForm({Category? category}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryFormScreen(category: category)),
    );
    if (result == true) {
      _loadAllData();
    }
  }

  void _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Menghapus kategori akan berpengaruh pada buku terkait. Yakin ingin melanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final success = await _apiService.deleteCategory(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori berhasil dihapus')));
          _loadAllData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus kategori')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Cari kategori...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.grey),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildCategoryListView()),
                _buildPaginationControls(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryListView() {
    if (_pagedCategories.isEmpty && !_isLoading) {
      return const Center(child: Text('Tidak ada kategori yang cocok.'));
    }
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        itemCount: _pagedCategories.length,
        itemBuilder: (context, index) {
          final category = _pagedCategories[index];
          
          // --- LOGIKA MENGHITUNG BUKU UNTUK SETIAP KATEGORI ---
          final int bookCount = _allBooks.where((book) => book.category.id == category.id).length;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade100,
                child: const Icon(Icons.category, color: Colors.indigo),
              ),
              title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              // --- TAMPILKAN JUMLAH BUKU ---
              subtitle: Text('$bookCount Buku', style: TextStyle(color: Colors.grey.shade600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _navigateToForm(category: category), tooltip: 'Edit'),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteCategory(category.id), tooltip: 'Hapus'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(onPressed: _currentPage == 1 ? null : _prevPage, child: const Text('<< Prev')),
          Text('Halaman $_currentPage dari $_totalPages'),
          ElevatedButton(onPressed: _currentPage == _totalPages ? null : _nextPage, child: const Text('Next >>')),
        ],
      ),
    );
  }
}