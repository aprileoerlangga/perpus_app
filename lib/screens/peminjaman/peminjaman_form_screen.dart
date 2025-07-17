import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/models/book.dart';

class PeminjamanFormScreen extends StatefulWidget {
  final Book book;
  const PeminjamanFormScreen({super.key, required this.book});

  @override
  State<PeminjamanFormScreen> createState() => _PeminjamanFormScreenState();
}

class _PeminjamanFormScreenState extends State<PeminjamanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  final TextEditingController _tglPinjamController = TextEditingController();
  final TextEditingController _tglKembaliController = TextEditingController();

  DateTime? _selectedTglPinjam;
  DateTime? _selectedTglKembali;

  @override
  void initState() {
    super.initState();
    // Set tanggal pinjam default ke hari ini
    _selectedTglPinjam = DateTime.now();
    _tglPinjamController.text = DateFormat('yyyy-MM-dd').format(_selectedTglPinjam!);
  }

  Future<void> _selectDate(BuildContext context, bool isTglPinjam) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isTglPinjam ? (_selectedTglPinjam ?? DateTime.now()) : (_selectedTglKembali ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
        if (isTglPinjam) {
          _selectedTglPinjam = picked;
          _tglPinjamController.text = formattedDate;
        } else {
          _selectedTglKembali = picked;
          _tglKembaliController.text = formattedDate;
        }
      });
    }
  }

  void _submitPeminjaman() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final memberId = await _apiService.getUserId();
      if (memberId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan ID Member. Silakan login ulang.')));
        setState(() => _isLoading = false);
        return;
      }

      // Kirim data ke API
      bool success = await _apiService.createPeminjaman(
        bookId: widget.book.id,
        memberId: memberId,
        tanggalPinjam: _tglPinjamController.text,
        tanggalKembali: _tglKembaliController.text,
      );

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buku berhasil dipinjam!')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal meminjam buku. Stok mungkin habis atau terjadi kesalahan.')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form Peminjaman Buku')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(widget.book.judul, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('oleh ${widget.book.pengarang}', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey)),
              const Divider(height: 32),
              TextFormField(
                controller: _tglPinjamController,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Peminjaman',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, true),
                validator: (v) => v!.isEmpty ? 'Tanggal peminjaman tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tglKembaliController,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Pengembalian (Batas)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, false),
                validator: (v) => v!.isEmpty ? 'Tanggal pengembalian tidak boleh kosong' : null,
              ),
              const SizedBox(height: 32),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitPeminjaman,
                    child: const Text('PINJAM BUKU INI'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}