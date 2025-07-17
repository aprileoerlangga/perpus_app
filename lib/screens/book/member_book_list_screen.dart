import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/screens/book/book_detail_screen.dart';
import 'dart:async';

class MemberBookListScreen extends StatefulWidget {
  final Category? category;
  const MemberBookListScreen({super.key, this.category});

  @override
  State<MemberBookListScreen> createState() => _MemberBookListScreenState();
}

class _MemberBookListScreenState extends State<MemberBookListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Book> _books = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialBooks();
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

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore && _hasMore && !_isLoading) {
      _loadMoreBooks();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadInitialBooks();
    });
  }

  Future<void> _loadInitialBooks() async {
    setState(() {
      _isLoading = true;
      _books = [];
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final BookResponse response = await _apiService.getBooks(
        query: _searchController.text,
        page: _currentPage,
        categoryId: widget.category?.id,
      );
      setState(() {
        _books = response.books;
        _hasMore = response.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _loadMoreBooks() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() { _isLoadingMore = true; });
    try {
      final BookResponse response = await _apiService.getBooks(
        query: _searchController.text,
        page: _currentPage + 1,
        categoryId: widget.category?.id,
      );
      setState(() {
        _books.addAll(response.books);
        _currentPage++;
        _hasMore = response.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() { _isLoadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category?.name ?? 'Daftar Buku'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari buku...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialBooks,
        child: _buildBookListView(),
      ),
    );
  }

  Widget _buildBookListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_books.isEmpty) {
      return Center(child: Text('Tidak ada buku dalam kategori ini.'));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _books.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _books.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final book = _books[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text(book.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(book.pengarang),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id, isFromMember: true)),
              );
            },
          ),
        );
      },
    );
  }
}