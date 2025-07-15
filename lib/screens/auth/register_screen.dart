import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      bool success = await _apiService.register(_nameController.text, _usernameController.text, _emailController.text, _passwordController.text, _confirmPasswordController.text);
      setState(() => _isLoading = false);
      if (success && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrasi berhasil! Silakan login.')),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrasi Gagal! Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Buat Akun Anda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.badge_outlined)), validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v!.isEmpty ? 'Username tidak boleh kosong' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email tidak valid' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v!.length < 8 ? 'Password minimal 8 karakter' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi Password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v != _passwordController.text ? 'Password tidak cocok' : null),
              const SizedBox(height: 24),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: _register, child: const Text('DAFTAR', style: TextStyle(fontSize: 16))),
            ],
          ),
        ),
      ),
    );
  }
}