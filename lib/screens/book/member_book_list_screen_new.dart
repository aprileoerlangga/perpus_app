// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:perpus_app/api/api_service.dart';
// import 'package:perpus_app/models/book.dart';
// import 'package:perpus_app/models/book_response.dart';
// import 'package:perpus_app/models/category.dart';
// import 'package:perpus_app/screens/book/book_detail_screen.dart';

// class MemberBookListScreen extends StatefulWidget {
//   final Category? category;
//   const MemberBookListScreen({super.key, this.category});

//   @override
//   State<MemberBookListScreen> createState() => _MemberBookListScreenState();
// }

// class _MemberBookListScreenState extends State<MemberBookListScreen> with TickerProviderStateMixin {
//   final ApiService _apiService = ApiService();
//   final ScrollController _scrollController = ScrollController();
//   final TextEditingController _searchController = TextEditingController();
//   Timer? _debounce;

//   // Animation controllers
//   late AnimationController _fadeController;
//   late Animation<double> _fadeAnimation;

//   // State untuk data
//   List<Book> _books = [];
//   List<Category> _categories = [];
//   int _currentPage = 1;
//   bool _hasMore = true;
//   bool _isLoading = true;
//   bool _isLoadingMore = false;

//   // State untuk filter
//   Category? _selectedCategory;
//   String _sortBy = 'judul'; // Default sort by title
//   bool _sortAscending = true;
//   String _viewMode = 'grid'; // grid or list
  
//   // State untuk statistik
//   int _totalBooks = 0;
//   int _totalCategories = 0;

//   @override
//   void initState() {
//     super.initState();
//     _initAnimations();
//     _fetchInitialData();
//     _scrollController.addListener(_onScroll);
//     _searchController.addListener(_onSearchChanged);
//   }

//   void _initAnimations() {
//     _fadeController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
    
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
//     );
    
//     _fadeController.forward();
//   }

//   @override
//   void dispose() {
//     _fadeController.dispose();
//     _scrollController.dispose();
//     _searchController.dispose();
//     _debounce?.cancel();
//     super.dispose();
//   }

//   Future<void> _fetchInitialData() async {
//     setState(() => _isLoading = true);
//     await _fetchCategories();
//     await _fetchTotalStatistics();
//     await _fetchBooks(isRefreshing: true);
//     if (mounted) setState(() => _isLoading = false);
//   }

//   Future<void> _fetchTotalStatistics() async {
//     try {
//       // Untuk mendapatkan semua data, kita perlu fetch semua halaman
//       int allBooksCount = 0;
//       bool hasMore = true;
//       int currentPage = 1;
      
//       while (hasMore) {
//         final pageResponse = await _apiService.getBooks(page: currentPage);
//         allBooksCount += pageResponse.books.length;
//         hasMore = pageResponse.hasMore;
//         currentPage++;
//       }
      
//       setState(() {
//         _totalBooks = allBooksCount;
//         _totalCategories = _categories.length;
//       });
//     } catch (e) {
//       // Fallback to current loaded data if API fails
//       _calculateStatistics();
//     }
//   }

//   void _calculateStatistics() {
//     _totalBooks = _books.length;
//     _totalCategories = _categories.length;
//   }

//   void _sortBooks() {
//     _books.sort((a, b) {
//       int comparison;
//       switch (_sortBy) {
//         case 'judul':
//           comparison = a.judul.toLowerCase().compareTo(b.judul.toLowerCase());
//           break;
//         case 'pengarang':
//           comparison = a.pengarang.toLowerCase().compareTo(b.pengarang.toLowerCase());
//           break;
//         case 'tahun':
//           comparison = a.tahun.compareTo(b.tahun);
//           break;
//         default:
//           comparison = a.judul.toLowerCase().compareTo(b.judul.toLowerCase());
//       }
//       return _sortAscending ? comparison : -comparison;
//     });
//   }

//   Future<void> _fetchCategories() async {
//     try {
//       _categories = await _apiService.getCategories();
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Gagal memuat kategori: ${e.toString()}")),
//         );
//       }
//     }
//   }

//   Future<void> _fetchBooks({bool isRefreshing = false}) async {
//     if (isRefreshing) {
//       setState(() {
//         _isLoading = true;
//         _books = [];
//         _currentPage = 1;
//         _hasMore = true;
//       });
//     }

//     if (_isLoadingMore || !_hasMore) return;
//     if (!isRefreshing) setState(() => _isLoadingMore = true);

//     try {
//       final BookResponse response = await _apiService.getBooks(
//         query: _searchController.text,
//         page: _currentPage,
//         categoryId: _selectedCategory?.id,
//       );
      
//       if (mounted) {
//         setState(() {
//           _books.addAll(response.books);
//           _currentPage++;
//           _hasMore = response.hasMore;
//           _isLoading = false;
//           _isLoadingMore = false;
//         });
//         _sortBooks();
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//           _isLoadingMore = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(e.toString())),
//         );
//       }
//     }
//   }
  
//   void _onScroll() {
//     if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
//         !_isLoadingMore && _hasMore && !_isLoading) {
//       _fetchBooks();
//     }
//   }

//   void _onSearchChanged() {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();
//     _debounce = Timer(const Duration(milliseconds: 500), () {
//       _fetchBooks(isRefreshing: true);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: RefreshIndicator(
//           onRefresh: _fetchInitialData,
//           child: CustomScrollView(
//             controller: _scrollController,
//             slivers: [
//               _buildModernAppBar(),
//               SliverToBoxAdapter(
//                 child: _buildStatsCards(),
//               ),
//               SliverToBoxAdapter(
//                 child: _buildSearchAndFilter(),
//               ),
//               _isLoading
//                   ? SliverFillRemaining(
//                       child: _buildLoadingState(),
//                     )
//                   : _buildBookGrid(),
//               if (_isLoadingMore)
//                 SliverToBoxAdapter(
//                   child: _buildLoadMoreIndicator(),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildModernAppBar() {
//     return SliverAppBar(
//       expandedHeight: 120,
//       floating: true,
//       pinned: true,
//       backgroundColor: Colors.white,
//       elevation: 0,
//       flexibleSpace: FlexibleSpaceBar(
//         background: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [
//                 Color(0xFF6366F1), // Indigo
//                 Color(0xFF8B5CF6), // Purple
//               ],
//             ),
//           ),
//           child: SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Icon(
//                           Icons.library_books_rounded,
//                           color: Colors.white,
//                           size: 24,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               widget.category?.name ?? 'Koleksi Buku',
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const Text(
//                               'Jelajahi koleksi perpustakaan',
//                               style: TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//       leading: IconButton(
//         icon: Container(
//           padding: const EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.black.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
//         ),
//         onPressed: () {
//           HapticFeedback.lightImpact();
//           Navigator.pop(context);
//         },
//       ),
//     );
//   }

//   Widget _buildStatsCards() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       child: Row(
//         children: [
//           Expanded(
//             child: _buildStatCard(
//               'Total Buku',
//               _totalBooks.toString(),
//               Icons.library_books,
//               const LinearGradient(
//                 colors: [Color(0xFF667eea), Color(0xFF764ba2)],
//               ),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: _buildStatCard(
//               'Kategori',
//               _totalCategories.toString(),
//               Icons.category,
//               const LinearGradient(
//                 colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatCard(String title, String value, IconData icon, LinearGradient gradient) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: gradient,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: gradient.colors.first.withOpacity(0.3),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(6),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(icon, color: Colors.white, size: 18),
//               ),
//               Flexible(
//                 child: Text(
//                   value,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white70,
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchAndFilter() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       child: Column(
//         children: [
//           // Search Bar
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.1),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: TextField(
//               controller: _searchController,
//               style: const TextStyle(
//                 color: Colors.black87,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//               decoration: InputDecoration(
//                 hintText: 'Cari buku berdasarkan judul, pengarang...',
//                 hintStyle: TextStyle(
//                   color: Colors.grey[500],
//                   fontSize: 15,
//                   fontWeight: FontWeight.w400,
//                 ),
//                 prefixIcon: Container(
//                   margin: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Colors.blue.shade400, Colors.indigo.shade400],
//                     ),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: const Icon(
//                     Icons.search,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                 ),
//                 suffixIcon: _searchController.text.isNotEmpty
//                     ? IconButton(
//                         icon: Icon(Icons.clear, color: Colors.grey[600]),
//                         onPressed: () {
//                           _searchController.clear();
//                         },
//                       )
//                     : null,
//                 border: InputBorder.none,
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 16,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
          
//           // Filter Row
//           Container(
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.1),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 // First Row: Category and Sort
//                 Row(
//                   children: [
//                     // Category Filter
//                     Expanded(
//                       flex: 2,
//                       child: _buildCategoryDropdown(),
//                     ),
//                     const SizedBox(width: 10),
                    
//                     // Sort Dropdown
//                     Expanded(
//                       child: _buildSortDropdown(),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
                
//                 // Second Row: View Mode Toggle (centered)
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     _buildViewModeToggle(),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCategoryDropdown() {
//     return GestureDetector(
//       onTap: _showModernCategorySelector,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [
//               Colors.white,
//               Colors.grey[50]!,
//             ],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//           border: Border.all(
//             color: _selectedCategory != null ? Colors.indigo.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
//             width: 1.5,
//           ),
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: (_selectedCategory != null ? Colors.indigo : Colors.grey).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Icon(
//                 Icons.category_rounded,
//                 size: 18,
//                 color: _selectedCategory != null ? Colors.indigo : Colors.grey[600],
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     'Kategori',
//                     style: TextStyle(
//                       fontSize: 11,
//                       color: Colors.grey[600],
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     _selectedCategory?.name ?? 'Semua Kategori',
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: _selectedCategory != null ? Colors.indigo : Colors.grey[800],
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               padding: const EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 color: Colors.grey.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: Icon(
//                 Icons.keyboard_arrow_down_rounded,
//                 size: 20,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSortDropdown() {
//     return GestureDetector(
//       onTap: _showModernSortSelector,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [
//               Colors.white,
//               Colors.grey[50]!,
//             ],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//           border: Border.all(
//             color: Colors.grey.withOpacity(0.2),
//             width: 1.5,
//           ),
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: Colors.orange.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Icon(
//                 _sortAscending ? Icons.sort_rounded : Icons.sort_rounded,
//                 size: 18,
//                 color: Colors.orange[700],
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     'Urutkan',
//                     style: TextStyle(
//                       fontSize: 11,
//                       color: Colors.grey[600],
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     _getSortDisplayName(_sortBy),
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.grey[800],
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               padding: const EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 color: Colors.grey.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: Icon(
//                 Icons.keyboard_arrow_down_rounded,
//                 size: 20,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildViewModeToggle() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _buildViewModeButton(Icons.grid_view, 'grid'),
//           _buildViewModeButton(Icons.list, 'list'),
//         ],
//       ),
//     );
//   }

//   Widget _buildViewModeButton(IconData icon, String mode) {
//     final isSelected = _viewMode == mode;
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _viewMode = mode;
//         });
//       },
//       child: Container(
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.blue : Colors.transparent,
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Icon(
//           icon,
//           size: 18,
//           color: isSelected ? Colors.white : Colors.grey[600],
//         ),
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return const Center(
//       child: SingleChildScrollView(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Memuat data buku...',
//               style: TextStyle(fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBookGrid() {
//     if (_books.isEmpty) {
//       return SliverFillRemaining(
//         child: Center(
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.library_books_outlined,
//                   size: 50,
//                   color: Colors.grey[300],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Tidak ada buku ditemukan',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey[600],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Coba ubah filter pencarian',
//                   style: TextStyle(
//                     fontSize: 10,
//                     color: Colors.grey[500],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return SliverPadding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       sliver: _viewMode == 'grid' ? _buildGridView() : _buildListView(),
//     );
//   }

//   Widget _buildGridView() {
//     return SliverGrid(
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         childAspectRatio: 0.6,
//         crossAxisSpacing: 16,
//         mainAxisSpacing: 16,
//       ),
//       delegate: SliverChildBuilderDelegate(
//         (context, index) {
//           return GestureDetector(
//             onTap: () => _showBookDetail(_books[index]),
//             child: _buildModernBookCard(_books[index]),
//           );
//         },
//         childCount: _books.length,
//       ),
//     );
//   }

//   Widget _buildListView() {
//     return SliverList(
//       delegate: SliverChildBuilderDelegate(
//         (context, index) {
//           return Padding(
//             padding: const EdgeInsets.only(bottom: 12),
//             child: GestureDetector(
//               onTap: () => _showBookDetail(_books[index]),
//               child: _buildBookListTile(_books[index]),
//             ),
//           );
//         },
//         childCount: _books.length,
//       ),
//     );
//   }

//   Widget _buildModernBookCard(Book book) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Book Image
//           Expanded(
//             flex: 3,
//             child: Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: Colors.grey[200],
//                 borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [Colors.blue.shade100, Colors.purple.shade100],
//                 ),
//               ),
//               child: (book.path?.isNotEmpty ?? false)
//                   ? ClipRRect(
//                       borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                       child: Image.network(
//                         'http://localhost:8000/storage/${book.path}',
//                         fit: BoxFit.cover,
//                         errorBuilder: (context, error, stackTrace) {
//                           return _buildBookPlaceholder(book);
//                         },
//                         loadingBuilder: (context, child, loadingProgress) {
//                           if (loadingProgress == null) return child;
//                           return const Center(
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           );
//                         },
//                       ),
//                     )
//                   : _buildBookPlaceholder(book),
//             ),
//           ),
          
//           // Book Info
//           Flexible(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.all(10),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Flexible(
//                     child: Text(
//                       book.judul,
//                       style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   const SizedBox(height: 3),
//                   Flexible(
//                     child: Text(
//                       book.pengarang,
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey[600],
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.calendar_today,
//                         size: 10,
//                         color: Colors.grey[500],
//                       ),
//                       const SizedBox(width: 3),
//                       Flexible(
//                         child: Text(
//                           book.tahun.toString(),
//                           style: TextStyle(
//                             fontSize: 10,
//                             color: Colors.grey[500],
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBookPlaceholder(Book book) {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [Colors.blue.shade100, Colors.purple.shade100],
//         ),
//       ),
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.auto_stories,
//               size: 40,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               book.judul,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Colors.grey[600],
//                 fontWeight: FontWeight.w500,
//               ),
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBookListTile(Book book) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 56,
//             height: 76,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(8),
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [Colors.blue.shade100, Colors.purple.shade100],
//               ),
//             ),
//             child: (book.path?.isNotEmpty ?? false)
//                 ? ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: Image.network(
//                       'http://localhost:8000/storage/${book.path}',
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Icon(
//                           Icons.auto_stories,
//                           color: Colors.grey[400],
//                           size: 28,
//                         );
//                       },
//                     ),
//                   )
//                 : Icon(
//                     Icons.auto_stories,
//                     color: Colors.grey[400],
//                     size: 28,
//                   ),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   book.judul,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 3),
//                 Text(
//                   book.pengarang,
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: Colors.grey[600],
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 6),
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.calendar_today,
//                       size: 13,
//                       color: Colors.grey[500],
//                     ),
//                     const SizedBox(width: 3),
//                     Text(
//                       book.tahun.toString(),
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey[500],
//                       ),
//                     ),
//                     const Spacer(),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.green.shade100,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Text(
//                         'Tersedia',
//                         style: TextStyle(
//                           fontSize: 9,
//                           color: Colors.green.shade700,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadMoreIndicator() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       alignment: Alignment.center,
//       child: const SizedBox(
//         width: 24,
//         height: 24,
//         child: CircularProgressIndicator(strokeWidth: 2),
//       ),
//     );
//   }

//   void _showBookDetail(Book book) {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => BookDetailScreen(bookId: book.id, isFromMember: true),
//       ),
//     );
//   }

//   // Helper method untuk mendapatkan nama display sort
//   String _getSortDisplayName(String sortBy) {
//     switch (sortBy) {
//       case 'judul':
//         return 'Judul ${_sortAscending ? 'A-Z' : 'Z-A'}';
//       case 'pengarang':
//         return 'Pengarang ${_sortAscending ? 'A-Z' : 'Z-A'}';
//       case 'tahun':
//         return 'Tahun ${_sortAscending ? 'Lama-Baru' : 'Baru-Lama'}';
//       default:
//         return 'Judul A-Z';
//     }
//   }

//   // Modern Category Selector Modal
//   void _showModernCategorySelector() {
//     HapticFeedback.lightImpact();
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => _buildModernCategoryModal(),
//     );
//   }

//   Widget _buildModernCategoryModal() {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.7,
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(24),
//           topRight: Radius.circular(24),
//         ),
//       ),
//       child: Column(
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.grey[50],
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(24),
//                 topRight: Radius.circular(24),
//               ),
//             ),
//             child: Column(
//               children: [
//                 // Handle bar
//                 Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[300],
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.indigo.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Icon(
//                         Icons.category_rounded,
//                         color: Colors.indigo,
//                         size: 24,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     const Text(
//                       'Pilih Kategori',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
          
//           // Search bar
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.grey[50],
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.grey.withOpacity(0.2)),
//               ),
//               child: TextField(
//                 decoration: InputDecoration(
//                   hintText: 'Cari kategori...',
//                   prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
//                   border: InputBorder.none,
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 ),
//                 onChanged: (value) {
//                   // Implement search functionality if needed
//                 },
//               ),
//             ),
//           ),
          
//           // Category list
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               children: [
//                 // All categories option
//                 _buildCategoryOption(
//                   null,
//                   'Semua Kategori',
//                   Icons.apps_rounded,
//                   Colors.indigo,
//                   '${_totalBooks} buku',
//                 ),
//                 const SizedBox(height: 12),
//                 // Individual categories
//                 ..._categories.map((category) => Padding(
//                   padding: const EdgeInsets.only(bottom: 12),
//                   child: _buildCategoryOption(
//                     category,
//                     category.name,
//                     Icons.folder_rounded,
//                     _getCategoryColor(category.id),
//                     '${_getBooksCountForCategory(category.id)} buku',
//                   ),
//                 )),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCategoryOption(Category? category, String name, IconData icon, Color color, String subtitle) {
//     final isSelected = _selectedCategory?.id == category?.id;
    
//     return GestureDetector(
//       onTap: () {
//         HapticFeedback.selectionClick();
//         setState(() {
//           _selectedCategory = category;
//         });
//         Navigator.pop(context);
//         _fetchBooks(isRefreshing: true);
//       },
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.indigo.withOpacity(0.1) : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isSelected ? Colors.indigo.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
//             width: isSelected ? 2 : 1,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(
//                 icon,
//                 color: color,
//                 size: 20,
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     name,
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                       color: isSelected ? Colors.indigo : Colors.grey[800],
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     subtitle,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (isSelected)
//               Container(
//                 padding: const EdgeInsets.all(4),
//                 decoration: BoxDecoration(
//                   color: Colors.indigo,
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.check,
//                   color: Colors.white,
//                   size: 16,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Modern Sort Selector Modal
//   void _showModernSortSelector() {
//     HapticFeedback.lightImpact();
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       builder: (context) => _buildModernSortModal(),
//     );
//   }

//   Widget _buildModernSortModal() {
//     final sortOptions = [
//       {'key': 'judul', 'name': 'Judul', 'icon': Icons.sort_by_alpha_rounded, 'color': Colors.blue},
//       {'key': 'pengarang', 'name': 'Pengarang', 'icon': Icons.person_rounded, 'color': Colors.green},
//       {'key': 'tahun', 'name': 'Tahun', 'icon': Icons.calendar_today_rounded, 'color': Colors.orange},
//     ];

//     return Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(24),
//           topRight: Radius.circular(24),
//         ),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.grey[50],
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(24),
//                 topRight: Radius.circular(24),
//               ),
//             ),
//             child: Column(
//               children: [
//                 Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[300],
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Icon(
//                         Icons.sort_rounded,
//                         color: Colors.orange[700],
//                         size: 24,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     const Text(
//                       'Urutkan Berdasarkan',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           // Sort options
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 ...sortOptions.map((option) => Padding(
//                   padding: const EdgeInsets.only(bottom: 12),
//                   child: _buildSortOption(
//                     option['key'] as String,
//                     option['name'] as String,
//                     option['icon'] as IconData,
//                     option['color'] as Color,
//                   ),
//                 )),
//                 const SizedBox(height: 8),
//                 // Sort direction toggle
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[50],
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.grey.withOpacity(0.2)),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
//                         color: Colors.indigo,
//                       ),
//                       const SizedBox(width: 12),
//                       Text(
//                         'Urutan: ${_sortAscending ? 'A ke Z / Lama ke Baru' : 'Z ke A / Baru ke Lama'}',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const Spacer(),
//                       Switch.adaptive(
//                         value: _sortAscending,
//                         onChanged: (value) {
//                           setState(() {
//                             _sortAscending = value;
//                           });
//                           _sortBooks();
//                         },
//                         activeColor: Colors.indigo,
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSortOption(String key, String name, IconData icon, Color color) {
//     final isSelected = _sortBy == key;
    
//     return GestureDetector(
//       onTap: () {
//         HapticFeedback.selectionClick();
//         setState(() {
//           _sortBy = key;
//         });
//         Navigator.pop(context);
//         _sortBooks();
//       },
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: isSelected ? color.withOpacity(0.1) : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isSelected ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
//             width: isSelected ? 2 : 1,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(
//                 icon,
//                 color: color,
//                 size: 20,
//               ),
//             ),
//             const SizedBox(width: 16),
//             Text(
//               name,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: isSelected ? color : Colors.grey[800],
//               ),
//             ),
//             const Spacer(),
//             if (isSelected)
//               Container(
//                 padding: const EdgeInsets.all(4),
//                 decoration: BoxDecoration(
//                   color: color,
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.check,
//                   color: Colors.white,
//                   size: 16,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Helper methods
//   Color _getCategoryColor(int categoryId) {
//     final colors = [
//       Colors.indigo,
//       Colors.blue,
//       Colors.green,
//       Colors.orange,
//       Colors.red,
//       Colors.purple,
//       Colors.teal,
//       Colors.amber,
//     ];
//     return colors[categoryId % colors.length];
//   }

//   int _getBooksCountForCategory(int categoryId) {
//     return _books.where((book) => book.category.id == categoryId).length;
//   }
// }
