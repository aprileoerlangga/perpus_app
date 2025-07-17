import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
import 'package:perpus_app/screens/book/book_detail_screen.dart';

class MemberBookListScreen extends StatefulWidget {
  const MemberBookListScreen({super.key});

  @override
  State<MemberBookListScreen> createState() => _MemberBookListScreenState();
}

class _MemberBookListScreenState extends State<MemberBookListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<Book> _books = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

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
      _loadInitialBooks(query: _searchController.text);
    });
  }

  Future<void> _loadInitialBooks({String? query}) async {
    setState(() {
      _isLoading = true;
      _books = [];
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final BookResponse response = await _apiService.getBooks(query: query, page: _currentPage);
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
    setState(() { _isLoadingMore = true; });
    try {
      final BookResponse response = await _apiService.getBooks(query: _searchController.text, page: _currentPage + 1);
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
        title: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari buku...',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadInitialBooks(query: _searchController.text),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBookListView(),
      ),
    );
  }

  Widget _buildBookListView() {
    if (_books.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Tidak ada buku tersedia.'
              : 'Tidak ada hasil untuk "${_searchController.text}".',
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _books.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _books.length) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final book = _books[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(book.id.toString())),
            title: Text(book.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(book.pengarang),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookDetailScreen(
                  bookId: book.id,
                  isFromMember: true, // Kirim flag ini untuk menandakan dari member
                )),
              );
            },
          ),
        );
      },
    );
  }
}