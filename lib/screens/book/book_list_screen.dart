import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/screens/book/book_detail_screen.dart';
import 'package:perpus_app/screens/book/book_form_screen.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // State untuk data
  List<Book> _books = [];
  List<Category> _categories = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // State untuk filter
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await _fetchCategories();
    await _fetchBooks(isRefreshing: true);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchCategories() async {
    try {
      _categories = await _apiService.getCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memuat kategori: ${e.toString()}")));
      }
    }
  }

  Future<void> _fetchBooks({bool isRefreshing = false}) async {
    if (isRefreshing) {
      setState(() {
        _isLoading = true;
        _books = [];
        _currentPage = 1;
        _hasMore = true;
      });
    }

    // Mencegah panggilan ganda saat sedang memuat
    if (_isLoadingMore || !_hasMore) return;
    if (!isRefreshing) setState(() => _isLoadingMore = true);

    try {
      final response = await _apiService.getBooks(
        query: _searchController.text,
        page: _currentPage,
        // Pastikan categoryId dikirim null jika _selectedCategory null
        categoryId: _selectedCategory?.id,
      );
      if (mounted) {
        setState(() {
          // Jika filter kategori aktif, hanya tampilkan buku yang sesuai kategori
          if (_selectedCategory != null) {
            _books.addAll(
              response.books.where((b) => b.category.id == _selectedCategory!.id),
            );
          } else {
            _books.addAll(response.books);
          }
          _currentPage++;
          _hasMore = response.hasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore && _hasMore) {
      _fetchBooks();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchBooks(isRefreshing: true);
    });
  }

  int get _totalStok => _books.fold(0, (sum, book) => sum + book.stok);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Buku'),
        actions: [ /* Tombol export/import Anda */ ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: Column(
            children: [
              _buildHeaderControls(),
              const Divider(height: 1),
              // Tampilkan loading di sini jika sedang memuat setelah filter/search
              _isLoading
                  ? const Expanded(child: Center(child: CircularProgressIndicator()))
                  : Expanded(child: _buildBookListView()),
            ],
          ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookFormScreen()));
          if (result == true) _fetchInitialData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeaderControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Kartu Statistik
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Judul', _books.length.toString(), Colors.indigo)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Total Stok', _totalStok.toString(), Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          // Kolom Pencarian
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari berdasarkan judul...',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          // Dropdown Filter Kategori
          DropdownButtonFormField<Category>(
            value: _selectedCategory,
            hint: const Text('Filter berdasarkan kategori'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
              ..._categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.name))),
            ],
            onChanged: (Category? newValue) {
              setState(() {
                _selectedCategory = newValue;
                // Reset page dan data buku setiap filter berubah
                _books = [];
                _currentPage = 1;
                _hasMore = true;
                _isLoading = true;
              });
              _fetchBooks(isRefreshing: true);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildBookListView() {
    if (_books.isEmpty) {
      return const Center(child: Text('Tidak ada buku yang cocok.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      controller: _scrollController,
      itemCount: _books.length + (_hasMore && _isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _books.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
        }
        final book = _books[index];
        final categoryName = _categories.firstWhere(
          (cat) => cat.id == book.category.id,
          orElse: () => Category(id: 0, name: 'Tanpa Kategori'),
        ).name;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text(book.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Kategori: $categoryName"),
            trailing: Text('Stok: ${book.stok}'),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
              );
              if (result == true) _fetchInitialData();
            },
          ),
        );
      },
    );
  }
}