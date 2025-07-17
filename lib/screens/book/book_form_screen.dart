import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart';

class BookFormScreen extends StatefulWidget {
  final Book? book;
  const BookFormScreen({super.key, this.book});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controller untuk setiap field
  late TextEditingController _judulController;
  late TextEditingController _pengarangController;
  late TextEditingController _penerbitController;
  late TextEditingController _tahunController;
  late TextEditingController _stokController;

  // State untuk menyimpan kategori yang dipilih
  int? _selectedCategoryId;
  bool _isLoading = false;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(text: widget.book?.judul ?? '');
    _pengarangController = TextEditingController(text: widget.book?.pengarang ?? '');
    _penerbitController = TextEditingController(text: widget.book?.penerbit ?? '');
    _tahunController = TextEditingController(text: widget.book?.tahun ?? '');
    _stokController = TextEditingController(text: widget.book?.stok.toString() ?? '');
    // Set kategori yang dipilih jika sedang mengedit buku
    _selectedCategoryId = widget.book?.category.id;
    // Ambil daftar kategori dari API
    _categoriesFuture = _apiService.getCategories();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Siapkan data untuk dikirim ke API
      final bookData = {
        'judul': _judulController.text,
        'category_id': _selectedCategoryId.toString(), // Pastikan category_id dikirim
        'pengarang': _pengarangController.text,
        'penerbit': _penerbitController.text,
        'tahun': _tahunController.text,
        'stok': _stokController.text,
      };
      
      bool success;
      if (widget.book == null) {
        // Mode Buat Baru
        success = await _apiService.addBook(bookData);
      } else {
        // Mode Edit
        success = await _apiService.updateBook(widget.book!.id, bookData);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil disimpan!'))
          );
          // Kembali ke halaman sebelumnya dan kirim sinyal 'true' untuk refresh
          Navigator.pop(context, true); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan data!'))
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book == null ? 'Tambah Buku Baru' : 'Edit Buku')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _judulController,
                  decoration: const InputDecoration(labelText: 'Judul Buku'),
                  validator: (v) => v!.isEmpty ? 'Judul tidak boleh kosong' : null
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pengarangController,
                  decoration: const InputDecoration(labelText: 'Pengarang'),
                  validator: (v) => v!.isEmpty ? 'Pengarang tidak boleh kosong' : null
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _penerbitController,
                  decoration: const InputDecoration(labelText: 'Penerbit'),
                  validator: (v) => v!.isEmpty ? 'Penerbit tidak boleh kosong' : null
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tahunController,
                  decoration: const InputDecoration(labelText: 'Tahun Terbit'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Tahun tidak boleh kosong' : null
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stokController,
                  decoration: const InputDecoration(labelText: 'Stok'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Stok tidak boleh kosong' : null
                ),
                const SizedBox(height: 16),
                // --- Dropdown untuk Memilih Kategori ---
                FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Tidak ada kategori tersedia. Tambahkan dulu di manajemen kategori.');
                    }
                    return DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      hint: const Text('Pilih Kategori'),
                      items: snapshot.data!.map((category) => DropdownMenuItem<int>(
                        value: category.id, 
                        child: Text(category.name)
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedCategoryId = value),
                      validator: (value) => value == null ? 'Pilih kategori' : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submitForm, child: const Text('SIMPAN')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}