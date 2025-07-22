import 'package:perpus_app/models/category.dart';

class Book {
  final int id;
  final String judul;
  final String pengarang;
  final String penerbit;
  final String tahun;
  final int stok;
  final Category category;
  final String? path; // For book cover/file path
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Book({
    required this.id,
    required this.judul,
    required this.pengarang,
    required this.penerbit,
    required this.tahun,
    required this.stok,
    required this.category,
    this.path,
    this.createdAt,
    this.updatedAt,
  });

  // Getter coverUrl: hanya return URL absolut jika path valid dan bukan default
  String? get coverUrl {
    if (path == null || path!.trim().isEmpty) return null;
    
    final cleanPath = path!.trim();
    
    if (cleanPath.contains('default-image.png')) return null;
    
    if (cleanPath.startsWith('http')) return cleanPath;
    
    // Hilangkan '/' di depan jika ada
    final fixedPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
    final finalUrl = 'http://perpus-api.mamorasoft.com/storage/$fixedPath';
    
    return finalUrl;
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      // Gunakan operator '??' untuk memberi nilai default jika null
      id: _parseId(json['id']),
      judul: json['judul']?.toString() ?? 'Tanpa Judul',
      pengarang: json['pengarang']?.toString() ?? 'Tanpa Pengarang',
      penerbit: json['penerbit']?.toString() ?? 'Tanpa Penerbit',
      tahun: json['tahun']?.toString() ?? '-',
      stok: _parseStok(json['stok']),
      path: json['path']?.toString(),

      // Beri penanganan khusus jika seluruh objek kategori null
      category: _parseCategory(json),

      // Parse timestamps if available
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  // Helper method to parse ID safely
  static int _parseId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  // Helper method to parse stock safely
  static int _parseStok(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  // Helper method to parse category
  static Category _parseCategory(Map<String, dynamic> json) {
    // Try different possible category field names
    if (json['category'] != null && json['category'] is Map<String, dynamic>) {
      return Category.fromJson(json['category']);
    }

    if (json['kategori'] != null && json['kategori'] is Map<String, dynamic>) {
      return Category.fromJson(json['kategori']);
    }

    // If category_id is provided, create a minimal category
    if (json['category_id'] != null) {
      return Category(
        id: _parseId(json['category_id']),
        name: json['category_name']?.toString() ??
            'Kategori ${json['category_id']}',
      );
    }

    // Default category
    return Category(id: 0, name: 'Tanpa Kategori');
  }

  // Helper method to parse DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'pengarang': pengarang,
      'penerbit': penerbit,
      'tahun': tahun,
      'stok': stok,
      'category_id': category.id,
      'path': path,
    };
  }

  // Convert to form data for API submission
  Map<String, String> toFormData() {
    return {
      'judul': judul,
      'pengarang': pengarang,
      'penerbit': penerbit,
      'tahun': tahun,
      'stok': stok.toString(),
      'category_id': category.id.toString(),
      if (path != null) 'path': path!,
    };
  }

  Book copyWith({
    int? id,
    String? judul,
    String? pengarang,
    String? penerbit,
    String? tahun,
    int? stok,
    Category? category,
    String? path,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      judul: judul ?? this.judul,
      pengarang: pengarang ?? this.pengarang,
      penerbit: penerbit ?? this.penerbit,
      tahun: tahun ?? this.tahun,
      stok: stok ?? this.stok,
      category: category ?? this.category,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}