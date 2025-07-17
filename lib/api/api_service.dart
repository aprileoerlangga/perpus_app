import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/user_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio;

  ApiService._()
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://perpus-api.mamorasoft.com/api',
          connectTimeout: const Duration(milliseconds: 5000),
          receiveTimeout: const Duration(milliseconds: 3000),
          headers: {'Accept': 'application/json'},
        )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  // --- SESSION & ROLE HELPERS ---
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }
  
  Future<void> _saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }
  
  // TAMBAHKAN FUNGSI UNTUK MENYIMPAN USER ID
  Future<void> _saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', id);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  // TAMBAHKAN FUNGSI UNTUK MENGAMBIL USER ID
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    await prefs.remove('user_id'); // Hapus juga user_id saat logout
  }

  // --- AUTH METHODS ---
  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post('/login', data: {'username': username, 'password': password});
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data['token'] != null && data['user'] != null) {
          await _saveToken(data['token']);
          await _saveUserName(data['user']['name']);
          await _saveUserId(data['user']['id']); // SIMPAN USER ID DI SINI
          if (data['user']['roles'] is List && data['user']['roles'].isNotEmpty) {
            await _saveUserRole(data['user']['roles'][0]['name']);
          } else {
            await _saveUserRole('member');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String name, String username, String email, String password, String confirmPassword) async {
    try {
      final response = await _dio.post('/register',
        data: {
          'name': name, 'username': username, 'email': email,
          'password': password, 'confirm_password': confirmPassword,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- BOOK CRUD ---
  Future<bool> addBook(Map<String, String> bookData) async {
    try {
      final response = await _dio.post('/book/create', data: bookData);
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      print('Error adding book: ${e.response?.data}');
      return false;
    }
  }
  
  Future<bool> updateBook(int id, Map<String, String> bookData) async {
    try {
      final response = await _dio.post('/book/$id/update', data: bookData);
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Error updating book: ${e.response?.data}');
      return false;
    }
  }

  Future<bool> deleteBook(int id) async {
    try {
      final response = await _dio.delete('/book/$id/delete');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<BookResponse> getBooks({int page = 1, String? query, int? categoryId}) async {
    try {
      String endpoint = categoryId != null
          ? '/book/filter/$categoryId'
          : '/book/all';

      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'page': page,
          if (query != null && query.isNotEmpty) 'search': query,
        },
      );
      
      final responseData = response.data;

      // ==================== LOGIKA PARSING FLEKSIBEL ====================
      if (responseData is Map<String, dynamic> && responseData['data'] != null) {
        final data = responseData['data'];
        
        // Cek 1: Apakah responsnya berhalaman (paginated)?
        if (data['books'] is Map<String, dynamic> && data['books']['data'] is List) {
          final bookData = data['books'];
          final List<dynamic> bookListJson = bookData['data'];
          final List<Book> books = bookListJson.map((json) => Book.fromJson(json)).toList();
          final bool hasMore = bookData['current_page'] < bookData['last_page'];
          return BookResponse(books: books, hasMore: hasMore);
        }
        
        // Cek 2: Apakah responsnya adalah daftar sederhana (simple list)?
        else if (data['books'] is List) {
          final List<dynamic> bookListJson = data['books'];
          final List<Book> books = bookListJson.map((json) => Book.fromJson(json)).toList();
          // Jika ini adalah daftar sederhana, kita anggap tidak ada halaman lagi
          return BookResponse(books: books, hasMore: false);
        }
      }
      
      // Jika tidak ada format yang cocok, kembalikan list kosong
      return BookResponse(books: [], hasMore: false);
      // ================================================================

    } catch (e) {
      throw Exception('Gagal mengambil data buku.');
    }
  }

  Future<Book> getBookById(int bookId) async {
    try {
      final response = await _dio.get('/book/$bookId');
      final responseData = response.data;
      
      // Pastikan path ke objek buku sudah benar sesuai respons API Anda
      if (responseData is Map<String, dynamic> &&
          responseData['data']?['book'] is Map<String, dynamic>) {
        
        // Langsung kirim seluruh objek buku ke Book.fromJson
        final Map<String, dynamic> bookJson = responseData['data']['book'];
        return Book.fromJson(bookJson);
      } else {
        throw Exception('Struktur data detail buku tidak terduga.');
      }
    } catch (e) {
      throw Exception('Gagal memuat detail buku.');
    }
  }

  Future<bool> addCategory(String categoryName) async {
    try {
      final response = await _dio.post('/category/create', data: {'nama_kategori': categoryName});
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      print('Error adding category: ${e.response?.data}');
      return false;
    }
  }

  Future<bool> updateCategory(int id, String categoryName) async {
    try {
      final response = await _dio.post('/category/update/$id',
          data: {'nama_kategori': categoryName});
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Error updating category: ${e.response?.data}');
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      final response = await _dio.delete('/category/$id/delete');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Category>> getCategories({String? query}) async {
    try {
      final Map<String, dynamic> queryParameters = {};
      if (query != null && query.isNotEmpty) {
        queryParameters['search'] = query;
      }
      final response = await _dio.get('/category/all/all', queryParameters: queryParameters);
      final responseData = response.data;
      if (responseData is Map<String, dynamic> &&
          responseData['data']['categories'] is List) {
        final List<dynamic> categoryList = responseData['data']['categories'];
        return categoryList.map((json) => Category.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Gagal memuat kategori.');
    }
  }

  // --- IMPORT & EXPORT METHODS (VERSI FINAL) ---

  Future<String?> exportBooksToExcel() async {
    try {
      // 1. Minta link, bukan file mentah
      final response = await _dio.get('/book/export/excel');

      // 2. Cek jika server merespons dengan sukses
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        // 3. Ambil path dari JSON, persis seperti PDF
        final String? filePath = response.data['path'];
        
        if (filePath != null) {
          // 4. Buat dan kembalikan URL lengkap
          return 'http://perpus-api.mamorasoft.com/$filePath';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> exportBooksToPdf() async {
    // Fungsi PDF ini sudah benar dari perbaikan kita sebelumnya
    try {
      final response = await _dio.get('/book/export/pdf');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final String? filePath = response.data['path'];
        if (filePath != null) {
          return 'http://perpus-api.mamorasoft.com/$filePath';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> importBooksFromExcel(List<int> fileBytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file_import': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });
      final response = await _dio.post('/book/import/excel', data: formData);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<UserResponse> getMembers({int page = 1, String? query}) async {
    try {
      // Siapkan parameter untuk dikirim ke API
      final Map<String, dynamic> queryParameters = {
        'page': page,
      };
      // Jika ada query pencarian, tambahkan ke parameter
      if (query != null && query.isNotEmpty) {
        queryParameters['search'] = query;
      }
      
      final response = await _dio.get('/user/member/all', queryParameters: queryParameters);
      
      final data = response.data['data'];
      final List<dynamic> userList = data['users']['data'];
      final users = userList.map((user) => User.fromJson(user)).toList();

      return UserResponse(
        users: users,
        currentPage: data['users']['current_page'],
        lastPage: data['users']['last_page'],
      );
    } catch (e) {
      throw Exception('Gagal mengambil data member.');
    }
  }

  Future<PeminjamanResponse> getPeminjamanList({int page = 1}) async {
    try {
      final response = await _dio.get('/peminjaman/all', queryParameters: {'page': page});
      final responseData = response.data;

      // PERBAIKAN: Sesuaikan dengan struktur JSON yang sebenarnya
      if (responseData is Map &&
          responseData['data'] is Map &&
          responseData['data']['peminjaman'] is List) { // Cek jika 'peminjaman' adalah sebuah List

        // Langsung ambil list dari 'peminjaman'
        final List peminjamanListJson = responseData['data']['peminjaman'];

        final List<Peminjaman> list = peminjamanListJson
            .map((json) => Peminjaman.fromJson(json as Map<String, dynamic>))
            .toList();

        // Asumsi sederhana: jika list yang didapat kurang dari 10, anggap tidak ada halaman lagi.
        // API Anda tidak menyertakan info paginasi di endpoint ini.
        final bool hasMore = list.length >= 10; 

        return PeminjamanResponse(peminjamanList: list, hasMore: hasMore);
      } else {
        // Jika struktur tidak sesuai, lempar error
        throw Exception('Struktur data peminjaman dari API tidak terduga.');
      }
    } on DioException catch (e) {
      // Menangani error dari Dio dengan lebih baik
      print(e.response?.data);
      throw Exception('Gagal memuat riwayat peminjaman. Error: ${e.message}');
    } catch (e) {
      throw Exception('Gagal memuat riwayat peminjaman.');
    }
  }

  // FUNGSI BARU UNTUK MEMBUAT PEMINJAMAN
  Future<bool> createPeminjaman({
    required int bookId,
    required int memberId,
    required String tanggalPinjam,
    required String tanggalKembali,
  }) async {
    try {
      final response = await _dio.post(
        '/peminjaman/book/$bookId/member/$memberId',
        data: {
          'tanggal_peminjaman': tanggalPinjam,
          'tanggal_pengembalian': tanggalKembali,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Gagal membuat peminjaman: $e');
      return false;
    }
  }

  // FUNGSI BARU UNTUK MENGEMBALIKAN BUKU
  Future<bool> returnBook(int peminjamanId) async {
    try {
      // Kita panggil endpoint 'accept' karena ia mengatur status ke '2' (Dikembalikan)
      final response = await _dio.get('/peminjaman/book/$peminjamanId/accept');
      
      // Ingat: Konsekuensinya adalah stok buku tidak kembali bertambah.
      return response.statusCode == 200;
    } catch (e) {
      print('Gagal mengembalikan buku: $e');
      return false;
    }
  }

  // FUNGSI UNTUK MENDAPATKAN RIWAYAT PEMINJAMAN MILIK MEMBER
  Future<PeminjamanResponse> getMyPeminjamanList({int page = 1, String? query}) async {
    // 1. Dapatkan ID user yang sedang login (ini sudah benar)
    final memberId = await getUserId();
    if (memberId == null) {
      return PeminjamanResponse(peminjamanList: [], hasMore: false);
    }
    try {
      // 2. Ambil SEMUA data peminjaman dari server
      // Kita abaikan parameter 'page' dan 'query' karena kita akan filter manual
      final response = await _dio.get('/peminjaman/all');
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data']['peminjaman'] is List) {

        final List<dynamic> allPeminjamanJson = responseData['data']['peminjaman'];

        // Ubah semua data JSON menjadi objek Peminjaman
        final List<Peminjaman> allPeminjaman = allPeminjamanJson
            .map((json) => Peminjaman.fromJson(json as Map<String, dynamic>))
            .toList();

        // ==================== LOGIKA FILTER DI SINI ====================
        // Saring daftar lengkap untuk hanya menampilkan data yang cocok dengan ID member
        final List<Peminjaman> myPeminjaman = allPeminjaman
            .where((peminjaman) => peminjaman.user.id == memberId)
            .toList();
        // ================================================================

        // Kirimkan data yang sudah difilter ke UI
        return PeminjamanResponse(peminjamanList: myPeminjaman, hasMore: false);

      } else {
        return PeminjamanResponse(peminjamanList: [], hasMore: false);
      }

    } catch (e) {
      print("Error di getMyPeminjamanList: $e");
      throw Exception('Gagal memuat riwayat peminjaman.');
    }
  }
}