import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';

class DashboardStatisticsWidget extends StatefulWidget {
  final bool isAdmin;
  final Duration refreshInterval;
  final Function(Map<String, dynamic>)? onDataUpdated;
  
  const DashboardStatisticsWidget({
    super.key,
    this.isAdmin = true,
    this.refreshInterval = const Duration(seconds: 30),
    this.onDataUpdated,
  });

  @override
  State<DashboardStatisticsWidget> createState() => _DashboardStatisticsWidgetState();
}

class _DashboardStatisticsWidgetState extends State<DashboardStatisticsWidget> 
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic> _statisticsData = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadStatistics();
    _startAutoRefresh();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(widget.refreshInterval, (timer) {
      if (mounted) {
        _loadStatistics(showLoading: false);
      }
    });
  }

  Future<void> _loadStatistics({bool showLoading = true}) async {
    try {
      if (showLoading) {
        setState(() => _isLoading = true);
      }

      final data = widget.isAdmin 
          ? await _apiService.getDashboardData()
          : await _apiService.getMemberDashboardData();

      if (mounted) {
        setState(() {
          _statisticsData = data;
          _isLoading = false;
        });
        
        // Trigger animation when data updates
        _pulseController.forward().then((_) {
          _pulseController.reverse();
        });
        
        if (!showLoading) {
          _fadeController.forward().then((_) {
            _fadeController.reverse();
          });
        } else {
          _fadeController.forward();
        }
        
        // Callback untuk parent widget
        if (widget.onDataUpdated != null) {
          widget.onDataUpdated!(data);
        }
        
        print('📊 Statistics updated: ${DateTime.now()}');
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : 4;
    final childAspectRatio = screenWidth < 600 ? 1.15 : 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.indigo[600],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Statistik Perpustakaan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            // Refresh button
            IconButton(
              onPressed: () => _loadStatistics(),
              icon: Icon(
                Icons.refresh,
                color: Colors.indigo[600],
              ),
              tooltip: 'Refresh Data',
            ),
            // Auto-refresh indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync,
                    color: Colors.green[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Auto',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _isLoading
            ? _buildLoadingCards(crossAxisCount, childAspectRatio)
            : FadeTransition(
                opacity: _fadeAnimation,
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: _buildStatisticCards(),
                ),
              ),
      ],
    );
  }

  Widget _buildLoadingCards(int crossAxisCount, double childAspectRatio) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: List.generate(widget.isAdmin ? 6 : 4, (index) => _buildLoadingCard()),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  List<Widget> _buildStatisticCards() {
    if (widget.isAdmin) {
      return [
        _buildStatCard(
          'Total Buku',
          '${_statisticsData['total_books'] ?? 0}',
          Icons.book_outlined,
          Colors.blue,
          'Koleksi perpustakaan',
          0,
        ),
        _buildStatCard(
          'Total Stok',
          '${_statisticsData['total_stock'] ?? 0}',
          Icons.inventory_2_outlined,
          Colors.green,
          'Stok keseluruhan',
          1,
        ),
        _buildStatCard(
          'Kategori',
          '${_statisticsData['total_categories'] ?? 0}',
          Icons.category_outlined,
          Colors.orange,
          'Jenis kategori',
          2,
        ),
        _buildStatCard(
          'Total Member',
          '${_statisticsData['total_members'] ?? 0}',
          Icons.people_outline,
          Colors.purple,
          'Member aktif',
          3,
        ),
        _buildStatCard(
          'Sedang Dipinjam',
          '${_statisticsData['total_borrowed'] ?? 0}',
          Icons.book_online_outlined,
          Colors.red,
          'Buku dipinjam',
          4,
        ),
        _buildStatCard(
          'Dikembalikan',
          '${_statisticsData['total_returned'] ?? 0}',
          Icons.assignment_return_outlined,
          Colors.teal,
          'Buku dikembalikan',
          5,
        ),
      ];
    } else {
      // Member dashboard
      return [
        _buildStatCard(
          'Total Member',
          '${_statisticsData['total_members'] ?? 0}',
          Icons.people_outline,
          Colors.blue,
          'Member terdaftar',
          0,
        ),
        _buildStatCard(
          'Meminjam Buku',
          '${_statisticsData['members_with_borrowings'] ?? 0}',
          Icons.book_online_outlined,
          Colors.green,
          'Member aktif',
          1,
        ),
        _buildStatCard(
          'Tidak Meminjam',
          '${_statisticsData['members_without_borrowings'] ?? 0}',
          Icons.person_outline,
          Colors.orange,
          'Member non-aktif',
          2,
        ),
        _buildStatCard(
          'Peminjaman Aktif',
          '${_statisticsData['total_active_borrowings'] ?? 0}',
          Icons.library_books_outlined,
          Colors.purple,
          'Buku dipinjam',
          3,
        ),
      ];
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.trending_up,
                              color: Colors.green[600],
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
