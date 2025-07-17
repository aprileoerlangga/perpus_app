class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  // Factory constructor untuk membuat instance Category dari JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['nama_kategori'] ?? 'Tanpa Kategori',
    );
  }
}