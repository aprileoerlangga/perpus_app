import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
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
  List<Category> _pagedCategories = [];

  bool _isLoading = true;
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllCategories();
    _searchController.addListener(_filterAndPaginate);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCategories() async {
    setState(() { _isLoading = true; });
    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _allCategories = categories;
        _filterAndPaginate();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kategori: ${e.toString()}')),
      );
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
      _loadAllCategories();
    }
  }

  // Ganti fungsi _deleteCategory dengan yang ini
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
          _loadAllCategories();
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
      return const Center(child: Text('Tidak ada kategori.'));
    }
    return ListView.builder(
      itemCount: _pagedCategories.length,
      itemBuilder: (context, index) {
        final category = _pagedCategories[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _navigateToForm(category: category)),
                IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteCategory(category.id)),
              ],
            ),
          ),
        );
      },
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