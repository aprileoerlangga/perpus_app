// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:perpus_app/api/api_service.dart';
// import 'package:perpus_app/models/peminjaman.dart';
// import 'package:perpus_app/models/peminjaman_response.dart';

// class PeminjamanListScreen extends StatefulWidget {
//   const PeminjamanListScreen({super.key});

//   @override
//   State<PeminjamanListScreen> createState() => _PeminjamanListScreenState();
// }

// class _PeminjamanListScreenState extends State<PeminjamanListScreen> with TickerProviderStateMixin {
//   // === State Management ===
//   final ApiService _apiService = ApiService();
//   final ScrollController _scrollController = ScrollController();
//   final TextEditingController _searchController = TextEditingController();
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   List<Peminjaman> _peminjamanList = [];
//   List<Peminjaman> _filteredList = [];
//   int _currentPage = 1;
//   bool _hasMore = true;
//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   String _searchQuery = '';
//   String _selectedStatus = 'all'; // all, borrowed, returned, overdue

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );
    
//     _loadInitial();
//     _scrollController.addListener(_onScroll);
//     _searchController.addListener(_onSearchChanged);
//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _searchController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged() {
//     setState(() {
//       _searchQuery = _searchController.text;
//       _applyFilters();
//     });
//   }

//   void _applyFilters() {
//     _filteredList = _peminjamanList.where((peminjaman) {
//       // Search filter
//       bool matchesSearch = _searchQuery.isEmpty ||
//           peminjaman.book.judul.toLowerCase().contains(_searchQuery.toLowerCase()) ||
//           peminjaman.user.name.toLowerCase().contains(_searchQuery.toLowerCase());

//       // Status filter
//       bool matchesStatus = _selectedStatus == 'all' || _getStatusForFilter(peminjaman) == _selectedStatus;

//       return matchesSearch && matchesStatus;
//     }).toList();
//   }

//   String _getStatusForFilter(Peminjaman peminjaman) {
//     if (peminjaman.status == '3') return 'returned';
    
//     final now = DateTime.now();
//     final dueDate = DateTime.parse(peminjaman.tanggalKembali);
    
//     if (now.isAfter(dueDate)) return 'overdue';
//     return 'borrowed';
//   }

//   void _onScroll() {
//     if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
//         !_isLoadingMore && _hasMore && !_isLoading) {
//       _loadMore();
//     }
//   }

//   Future<void> _loadInitial() async {
//     setState(() {
//       _isLoading = true;
//       _peminjamanList = [];
//       _filteredList = [];
//       _currentPage = 1;
//       _hasMore = true;
//     });
//     try {
//       final PeminjamanResponse response = await _apiService.getPeminjamanList(page: _currentPage);
//       setState(() {
//         _peminjamanList = response.peminjamanList;
//         _applyFilters();
//         _hasMore = response.hasMore;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() { _isLoading = false; });
//       if(mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: ${e.toString()}'),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _loadMore() async {
//     if (_isLoadingMore) return;
//     setState(() { _isLoadingMore = true; });
//     try {
//       final PeminjamanResponse response = await _apiService.getPeminjamanList(page: _currentPage + 1);
//       setState(() {
//         _peminjamanList.addAll(response.peminjamanList);
//         _applyFilters();
//         _currentPage++;
//         _hasMore = response.hasMore;
//         _isLoadingMore = false;
//       });
//     } catch (e) {
//       setState(() { _isLoadingMore = false; });
//     }
//   }

//   // === Statistics Calculation ===
//   Map<String, int> _getStatistics() {
//     int borrowed = 0, returned = 0, overdue = 0;
    
//     for (var peminjaman in _peminjamanList) {
//       switch (_getStatusForFilter(peminjaman)) {
//         case 'borrowed':
//           borrowed++;
//           break;
//         case 'returned':
//           returned++;
//           break;
//         case 'overdue':
//           overdue++;
//           break;
//       }
//     }
    
//     return {
//       'total': _peminjamanList.length,
//       'borrowed': borrowed,
//       'returned': returned,
//       'overdue': overdue,
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: _buildModernAppBar(),
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: Column(
//           children: [
//             // Search and Filter Section
//             _buildSearchSection(),
//             // Statistics Cards
//             if (!_isLoading) _buildStatisticsCards(),
//             // Content
//             Expanded(
//               child: RefreshIndicator(
//                 onRefresh: _loadInitial,
//                 color: const Color(0xFF1976D2),
//                 backgroundColor: Colors.white,
//                 child: _isLoading
//                     ? _buildLoadingState()
//                     : _filteredList.isEmpty
//                         ? _buildEmptyState()
//                         : _buildPeminjamanList(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   PreferredSizeWidget _buildModernAppBar() {
//     return AppBar(
//       elevation: 0,
//       backgroundColor: Colors.transparent,
//       flexibleSpace: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Color(0xFF1976D2),
//               Color(0xFF1E88E5),
//               Color(0xFF42A5F5),
//             ],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Color(0x1A000000),
//               offset: Offset(0, 2),
//               blurRadius: 8,
//             ),
//           ],
//         ),
//       ),
//       title: const Text(
//         'Riwayat Peminjaman',
//         style: TextStyle(
//           color: Colors.white,
//           fontWeight: FontWeight.bold,
//           fontSize: 22,
//           letterSpacing: 0.5,
//         ),
//       ),
//       centerTitle: true,
//       iconTheme: const IconThemeData(color: Colors.white),
//       actions: [
//         Container(
//           margin: const EdgeInsets.only(right: 12),
//           child: IconButton(
//             icon: const Icon(Icons.refresh_rounded, size: 24),
//             onPressed: _loadInitial,
//             tooltip: 'Refresh',
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSearchSection() {
//     return Container(
//       color: Colors.white,
//       child: Column(
//         children: [
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//             child: Container(
//               decoration: BoxDecoration(
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.04),
//                     offset: const Offset(0, 2),
//                     blurRadius: 8,
//                   ),
//                 ],
//               ),
//               child: TextField(
//                 controller: _searchController,
//                 decoration: InputDecoration(
//                   hintText: 'Cari berdasarkan judul buku atau nama peminjam...',
//                   hintStyle: TextStyle(
//                     color: Colors.grey[500],
//                     fontSize: 16,
//                   ),
//                   prefixIcon: Container(
//                     margin: const EdgeInsets.all(12),
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF1976D2).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.search_rounded, 
//                       color: Color(0xFF1976D2),
//                       size: 20,
//                     ),
//                   ),
//                   filled: true,
//                   fillColor: const Color(0xFFF8FAFC),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(16),
//                     borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(16),
//                     borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(16),
//                     borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//                 ),
//               ),
//             ),
//           ),
//           // Filter Chips
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: [
//                   _buildFilterChip('Semua', 'all', Icons.list_alt_rounded),
//                   const SizedBox(width: 12),
//                   _buildFilterChip('Dipinjam', 'borrowed', Icons.library_books_rounded),
//                   const SizedBox(width: 12),
//                   _buildFilterChip('Dikembalikan', 'returned', Icons.check_circle_rounded),
//                   const SizedBox(width: 12),
//                   _buildFilterChip('Terlambat', 'overdue', Icons.warning_amber_rounded),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }

//   Widget _buildFilterChip(String label, String value, IconData icon) {
//     final isSelected = _selectedStatus == value;
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       child: FilterChip(
//         avatar: Icon(
//           icon,
//           size: 18,
//           color: isSelected ? Colors.white : const Color(0xFF1976D2),
//         ),
//         label: Text(
//           label,
//           style: TextStyle(
//             color: isSelected ? Colors.white : const Color(0xFF1976D2),
//             fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         selected: isSelected,
//         onSelected: (selected) {
//           setState(() {
//             _selectedStatus = value;
//             _applyFilters();
//           });
//         },
//         selectedColor: const Color(0xFF1976D2),
//         checkmarkColor: Colors.white,
//         backgroundColor: Colors.white,
//         side: BorderSide(
//           color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFE2E8F0),
//           width: 1.5,
//         ),
//         elevation: isSelected ? 4 : 0,
//         shadowColor: const Color(0xFF1976D2).withOpacity(0.3),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       ),
//     );
//   }

//   Widget _buildStatisticsCards() {
//     final stats = _getStatistics();
    
//     return Container(
//       color: Colors.white,
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
//         child: Row(
//           children: [
//             Expanded(child: _buildStatCard('Total', stats['total']!, Icons.library_books, const Color(0xFF1976D2))),
//             const SizedBox(width: 12),
//             Expanded(child: _buildStatCard('Dipinjam', stats['borrowed']!, Icons.schedule, const Color(0xFFFF9800))),
//             const SizedBox(width: 12),
//             Expanded(child: _buildStatCard('Kembali', stats['returned']!, Icons.check_circle, const Color(0xFF4CAF50))),
//             const SizedBox(width: 12),
//             Expanded(child: _buildStatCard('Terlambat', stats['overdue']!, Icons.warning, const Color(0xFFF44336))),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatCard(String title, int count, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: color.withOpacity(0.2)),
//         boxShadow: [
//           BoxShadow(
//             color: color.withOpacity(0.1),
//             offset: const Offset(0, 2),
//             blurRadius: 8,
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, color: color, size: 20),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             count.toString(),
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 12,
//               color: color,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(32),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(24),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.08),
//                   offset: const Offset(0, 4),
//                   blurRadius: 20,
//                 ),
//               ],
//             ),
//             child: const CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
//               strokeWidth: 3,
//             ),
//           ),
//           const SizedBox(height: 24),
//           const Text(
//             'Memuat riwayat peminjaman...',
//             style: TextStyle(
//               fontSize: 16,
//               color: Color(0xFF64748B),
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: SingleChildScrollView(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(40),
//               margin: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(24),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.08),
//                     offset: const Offset(0, 4),
//                     blurRadius: 20,
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(24),
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           const Color(0xFF1976D2).withOpacity(0.1),
//                           const Color(0xFF42A5F5).withOpacity(0.05),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(60),
//                     ),
//                     child: const Icon(
//                       Icons.library_books_outlined,
//                       size: 72,
//                       color: Color(0xFF1976D2),
//                     ),
//                   ),
//                   const SizedBox(height: 32),
//                   Text(
//                     _searchQuery.isNotEmpty || _selectedStatus != 'all' 
//                       ? 'Tidak Ada Hasil' 
//                       : 'Belum Ada Riwayat',
//                     style: const TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF1E293B),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     _searchQuery.isNotEmpty || _selectedStatus != 'all'
//                       ? 'Coba ubah kata kunci pencarian atau filter'
//                       : 'Riwayat peminjaman akan ditampilkan di sini',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       color: Color(0xFF64748B),
//                       height: 1.5,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   if (_searchQuery.isNotEmpty || _selectedStatus != 'all') ...[
//                     const SizedBox(height: 24),
//                     ElevatedButton.icon(
//                       onPressed: () {
//                         setState(() {
//                           _searchController.clear();
//                           _selectedStatus = 'all';
//                           _applyFilters();
//                         });
//                       },
//                       icon: const Icon(Icons.clear_all, size: 18),
//                       label: const Text('Reset Filter'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF1976D2),
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPeminjamanList() {
//     return ListView.builder(
//       controller: _scrollController,
//       padding: const EdgeInsets.all(20),
//       itemCount: _filteredList.length + (_isLoadingMore ? 1 : 0),
//       itemBuilder: (context, index) {
//         if (index == _filteredList.length) {
//           return _buildLoadMoreIndicator();
//         }
        
//         final peminjaman = _filteredList[index];
//         return _buildModernPeminjamanItem(peminjaman, index);
//       },
//     );
//   }

//   Widget _buildLoadMoreIndicator() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       child: const Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
//         ),
//       ),
//     );
//   }

//   Widget _buildModernPeminjamanItem(Peminjaman peminjaman, int index) {
//     // Status Logic
//     String statusText;
//     Color statusColor;
//     Color statusBgColor;
//     IconData statusIcon;

//     if (peminjaman.status == '3') {
//       statusText = 'Dikembalikan';
//       statusColor = const Color(0xFF059669);
//       statusBgColor = const Color(0xFFECFDF5);
//       statusIcon = Icons.check_circle_rounded;
//     } else {
//       final now = DateTime.now();
//       final dueDate = DateTime.parse(peminjaman.tanggalKembali);
      
//       if (now.isAfter(dueDate)) {
//         final overdueDays = now.difference(dueDate).inDays;
//         statusText = 'Terlambat $overdueDays hari';
//         statusColor = const Color(0xFFDC2626);
//         statusBgColor = const Color(0xFFFEF2F2);
//         statusIcon = Icons.warning_amber_rounded;
//       } else {
//         statusText = 'Dipinjam';
//         statusColor = const Color(0xFFEA580C);
//         statusBgColor = const Color(0xFFFFF7ED);
//         statusIcon = Icons.schedule_rounded;
//       }
//     }

//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             offset: const Offset(0, 2),
//             blurRadius: 12,
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header dengan gradien
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   const Color(0xFF1976D2).withOpacity(0.08),
//                   const Color(0xFF42A5F5).withOpacity(0.04),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(20),
//                 topRight: Radius.circular(20),
//               ),
//             ),
//             child: Row(
//               children: [
//                 // Book Icon
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF1976D2), Color(0xFF1E88E5)],
//                     ),
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFF1976D2).withOpacity(0.3),
//                         offset: const Offset(0, 2),
//                         blurRadius: 8,
//                       ),
//                     ],
//                   ),
//                   child: const Icon(
//                     Icons.book_rounded,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 // Book Info
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         peminjaman.book.judul,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 18,
//                           color: Color(0xFF1E293B),
//                           height: 1.3,
//                         ),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 6),
//                       Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: const Color(0xFF64748B).withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                             child: Icon(
//                               Icons.person_outline_rounded,
//                               size: 16,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               peminjaman.user.name,
//                               style: TextStyle(
//                                 color: Colors.grey[600],
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Status Badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: statusBgColor,
//                     borderRadius: BorderRadius.circular(24),
//                     border: Border.all(color: statusColor.withOpacity(0.2)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         statusIcon,
//                         size: 16,
//                         color: statusColor,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         statusText,
//                         style: TextStyle(
//                           color: statusColor,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
          
//           // Content dengan info tanggal
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildModernInfoRow(
//                   Icons.calendar_today_rounded, 
//                   'Tanggal Pinjam', 
//                   peminjaman.tanggalPinjam,
//                   const Color(0xFF1976D2),
//                 ),
//                 const SizedBox(height: 16),
//                 _buildModernInfoRow(
//                   Icons.event_busy_rounded, 
//                   'Batas Kembali', 
//                   peminjaman.tanggalKembali,
//                   const Color(0xFFEA580C),
//                 ),
                
//                 // Tampilkan tanggal pengembalian HANYA jika sudah dikembalikan
//                 if (peminjaman.status == '3' && peminjaman.tanggalPengembalian != null) ...[
//                   const SizedBox(height: 16),
//                   _buildModernInfoRow(
//                     Icons.event_available_rounded, 
//                     'Dikembalikan Pada', 
//                     peminjaman.tanggalPengembalian!,
//                     const Color(0xFF059669),
//                   ),
                  
//                   // Informasi keterlambatan/keceptan
//                   () {
//                     final returnDate = DateTime.parse(peminjaman.tanggalPengembalian!);
//                     final dueDate = DateTime.parse(peminjaman.tanggalKembali);
//                     final daysDifference = returnDate.difference(dueDate).inDays;
                    
//                     if (daysDifference > 0) {
//                       return Column(
//                         children: [
//                           const SizedBox(height: 16),
//                           _buildModernInfoRow(
//                             Icons.warning_amber_rounded, 
//                             'Terlambat', 
//                             '$daysDifference hari setelah batas waktu',
//                             const Color(0xFFDC2626),
//                           ),
//                         ],
//                       );
//                     } else if (daysDifference < 0) {
//                       return Column(
//                         children: [
//                           const SizedBox(height: 16),
//                           _buildModernInfoRow(
//                             Icons.check_circle_rounded, 
//                             'Tepat Waktu', 
//                             '${daysDifference.abs()} hari sebelum batas',
//                             const Color(0xFF059669),
//                           ),
//                         ],
//                       );
//                     }
//                     return const SizedBox.shrink();
//                   }(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildModernInfoRow(IconData icon, String label, String? value, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.15)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(
//               icon,
//               size: 20,
//               color: color,
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: color,
//                     fontWeight: FontWeight.w600,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   value ?? '-',
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
