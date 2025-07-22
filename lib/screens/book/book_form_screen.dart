import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart' as category_model;

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
  bool _hasChanges = false; // Track perubahan form
  late Future<List<category_model.Category>> _categoriesFuture;
  
  // For image picking
  File? _selectedImage;
  XFile? _selectedImageWeb; // For web
  final ImagePicker _picker = ImagePicker();

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
    
    // Tambahkan listener untuk mendeteksi perubahan
    _judulController.addListener(_onFormChanged);
    _pengarangController.addListener(_onFormChanged);
    _penerbitController.addListener(_onFormChanged);
    _tahunController.addListener(_onFormChanged);
    _stokController.addListener(_onFormChanged);
    
    // Ambil daftar kategori dari API
    _categoriesFuture = _apiService.getCategories();
  }

  void _onFormChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImageWeb = image;
          } else {
            _selectedImage = File(image.path);
          }
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _pengarangController.dispose();
    _penerbitController.dispose();
    _tahunController.dispose();
    _stokController.dispose();
    super.dispose();
  }

  // Fungsi untuk konfirmasi kembali jika ada perubahan
  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true; // Boleh kembali jika tidak ada perubahan
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[600], size: 28),
            const SizedBox(width: 12),
            const Text('Perubahan Belum Disimpan'),
          ],
        ),
        content: const Text(
          'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Lanjut Edit',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  Map<String, String> _prepareBookData() {
    return {
      'judul': _judulController.text,
      'category_id': _selectedCategoryId.toString(), // Pastikan category_id dikirim
      'pengarang': _pengarangController.text,
      'penerbit': _penerbitController.text,
      'tahun': _tahunController.text,
      'stok': _stokController.text,
    };
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Siapkan data untuk dikirim ke API
        final bookData = _prepareBookData();
        
        bool success;
        if (widget.book == null) {
          // Mode Buat Baru - kirim baik File maupun XFile ke API
          success = await _apiService.addBook(bookData, _selectedImage, _selectedImageWeb);
        } else {
          // Mode Edit - kirim baik File maupun XFile ke API
          success = await _apiService.updateBook(widget.book!.id, bookData, _selectedImage, _selectedImageWeb);
        }

        setState(() => _isLoading = false);

        if (mounted) {
          if (success) {
            // Reset flag perubahan karena data sudah tersimpan
            setState(() => _hasChanges = false);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      widget.book == null ? 
                        'Buku berhasil ditambahkan!' : 
                        'Buku berhasil diperbarui!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Tambahkan delay kecil untuk memastikan gambar sudah diproses server
            if (widget.book == null && (_selectedImage != null || _selectedImageWeb != null)) {
              await Future.delayed(const Duration(seconds: 1));
            }
            
            // Kembali ke halaman sebelumnya dan kirim sinyal 'true' untuk refresh
            Navigator.pop(context, true); 
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Gagal menyimpan data! Periksa koneksi internet dan coba lagi.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          // Parse error message to provide better user feedback
          String errorMessage = e.toString();
          bool isServerImageError = errorMessage.contains('Server error:') || 
                                  errorMessage.contains('store() on null') ||
                                  e.toString().contains('Call to a member function store()');
          
          if (isServerImageError && (_selectedImage != null || _selectedImageWeb != null)) {
            // Show dialog offering to submit without image
            final shouldRetry = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    const Text('Masalah Server'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server memiliki masalah dengan upload gambar. Data buku lainnya masih bisa disimpan.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Apakah Anda ingin mencoba menyimpan buku tanpa gambar?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Simpan Tanpa Gambar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            
            if (shouldRetry == true) {
              // Try again without image
              setState(() => _isLoading = true);
              try {
                final bookDataRetry = _prepareBookData();
                bool success;
                if (widget.book == null) {
                  success = await _apiService.addBook(bookDataRetry, null, null);
                } else {
                  success = await _apiService.updateBook(widget.book!.id, bookDataRetry, null, null);
                }
                
                setState(() => _isLoading = false);
                
                if (success && mounted) {
                  setState(() => _hasChanges = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.book == null ? "Buku berhasil ditambahkan" : "Buku berhasil diperbarui"} (tanpa gambar)!',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Navigator.pop(context, true);
                  return;
                }
              } catch (retryError) {
                setState(() => _isLoading = false);
                errorMessage = 'Masih gagal menyimpan: ${retryError.toString()}';
              }
            } else {
              return; // User cancelled, don't show error message
            }
          }
          
          if (errorMessage.contains('Server error:')) {
            errorMessage = 'Masalah server: Tidak dapat menyimpan data. Silakan hubungi administrator.';
          } else if (errorMessage.contains('Validation error:')) {
            errorMessage = errorMessage.replaceFirst('Validation error: ', '');
          } else if (errorMessage.contains('File terlalu besar')) {
            errorMessage = 'Ukuran gambar terlalu besar. Pilih gambar dengan ukuran lebih kecil (maksimal 2MB).';
          } else if (errorMessage.contains('Exception:')) {
            errorMessage = errorMessage.replaceFirst('Exception: ', '');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Tutup',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(widget.book == null ? 'Tambah Buku Baru' : 'Edit Buku'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.grey[700],
                size: 20,
              ),
            ),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            if (_hasChanges)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Belum Disimpan',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            widget.book == null ? Icons.add_box : Icons.edit,
                            size: 48,
                            color: Colors.indigo,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.book == null ? 'Tambah Buku Baru' : 'Edit Informasi Buku',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Image Upload Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.image, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Cover Buku',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedImage != null && !kIsWeb)
                          Container(
                            height: 150,
                            width: 100,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else if (_selectedImageWeb != null && kIsWeb)
                          Container(
                            height: 150,
                            width: 100,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _selectedImageWeb!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                  Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400])),
                              ),
                            ),
                          )
                        else if (widget.book?.coverUrl != null)
                          Container(
                            height: 150,
                            width: 100,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.book!.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                  Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400])),
                              ),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: Text((_selectedImage != null || _selectedImageWeb != null || widget.book?.coverUrl != null) ? 'Ganti Gambar' : 'Pilih Gambar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.blue[700],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Form Fields
                  TextFormField(
                    controller: _judulController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Buku',
                      prefixIcon: Icon(Icons.book),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Judul tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _pengarangController,
                    decoration: const InputDecoration(
                      labelText: 'Pengarang',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Pengarang tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _penerbitController,
                    decoration: const InputDecoration(
                      labelText: 'Penerbit',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Penerbit tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _tahunController,
                    decoration: const InputDecoration(
                      labelText: 'Tahun Terbit',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Tahun tidak boleh kosong';
                      }
                      final year = int.tryParse(v);
                      if (year == null || year < 1000 || year > DateTime.now().year) {
                        return 'Masukkan tahun yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _stokController,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Stok',
                      prefixIcon: Icon(Icons.inventory),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Stok tidak boleh kosong';
                      }
                      final stock = int.tryParse(v);
                      if (stock == null || stock < 0) {
                        return 'Masukkan jumlah stok yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Dropdown untuk Memilih Kategori ---
                  FutureBuilder<List<category_model.Category>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error memuat kategori: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Card(
                          color: Colors.orange.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Tidak ada kategori tersedia. Tambahkan kategori terlebih dahulu di menu manajemen kategori.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Buku',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        hint: const Text('Pilih Kategori'),
                        items: snapshot.data!.map((category) => DropdownMenuItem<int>(
                          value: category.id, 
                          child: Text(category.name)
                        )).toList(),
                        onChanged: (value) => setState(() {
                          _selectedCategoryId = value;
                          _onFormChanged(); // Deteksi perubahan kategori
                        }),
                        validator: (value) => value == null ? 'Pilih kategori buku' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              widget.book == null ? 'TAMBAH BUKU' : 'PERBARUI BUKU',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  
                  // Tombol Kembali
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        final canPop = await _onWillPop();
                        if (canPop && mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Kembali',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}