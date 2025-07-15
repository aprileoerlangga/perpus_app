import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
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

  void _exportBooks() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mempersiapkan file export...')));
    try {
      final Uint8List fileBytes = await _apiService.exportBooksToExcel();
      final String fileName = 'daftar_buku_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await FileSaver.instance.saveFile(name: fileName, bytes: fileBytes, ext: 'xlsx', mimeType: MimeType.microsoftExcel);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File berhasil diekspor!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengekspor file: ${e.toString()}')));
      }
    }
  }

  void _exportBooksToPdf() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mempersiapkan file PDF...')));
    try {
      final Uint8List fileBytes = await _apiService.exportBooksToPdf();
      final String fileName = 'daftar_buku_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await FileSaver.instance.saveFile(name: fileName, bytes: fileBytes, ext: 'pdf', mimeType: MimeType.pdf);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File PDF berhasil diekspor!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengekspor PDF: ${e.toString()}')));
      }
    }
  }

  void _importBooks() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null && result.files.single.bytes != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengunggah file...')));
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      final success = await _apiService.importBooksFromExcel(fileBytes, fileName);
      if (mounted) {
         ScaffoldMessenger.of(context).removeCurrentSnackBar();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File berhasil diimpor! Daftar buku diperbarui.')));
          _loadInitialBooks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengimpor file.')));
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
        actions: [
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _importBooks, tooltip: 'Import dari Excel'),
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportBooks, tooltip: 'Export ke Excel'),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportBooksToPdf, tooltip: 'Export ke PDF'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadInitialBooks(query: _searchController.text),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBookListView(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookFormScreen()));
          if (result == true) {
            _loadInitialBooks();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBookListView() {
    if (_books.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Tidak ada buku.'
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
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
              );
              if (result == true) {
                _loadInitialBooks(query: _searchController.text);
              }
            },
          ),
        );
      },
    );
  }
}