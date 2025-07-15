import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
import 'package:perpus_app/models/category.dart';
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/user_response.dart';
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
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

  Future<BookResponse> getBooks({String? query, int page = 1}) async {
    try {
      final Map<String, dynamic> queryParameters = {'page': page};
      if (query != null && query.isNotEmpty) {
        queryParameters['search'] = query;
      }
      final response = await _dio.get('/book/all', queryParameters: queryParameters);
      final responseData = response.data;
      if (responseData is Map<String, dynamic> &&
          responseData['data']['books'] is Map<String, dynamic> &&
          responseData['data']['books']['data'] is List) {
        
        final bookData = responseData['data']['books'];
        final List<dynamic> bookListJson = bookData['data'];
        final List<Book> books = bookListJson.map((json) => Book.fromJson(json)).toList();
        final bool hasMore = bookData['current_page'] < bookData['last_page'];
        return BookResponse(books: books, hasMore: hasMore);
      } else {
        return BookResponse(books: [], hasMore: false);
      }
    } catch (e) {
      throw Exception('Gagal mengambil data buku.');
    }
  }

  Future<Book> getBookById(int bookId) async {
    try {
      final response = await _dio.get('/book/$bookId');
      final responseData = response.data;
      if (responseData is Map<String, dynamic> &&
          responseData['data']['book'] is Map<String, dynamic>) {
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

  // --- IMPORT & EXPORT METHODS ---

  Future<Uint8List> exportBooksToExcel() async {
    try {
      final response = await _dio.get(
        '/book/export/excel',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Gagal mengekspor data Excel.');
    }
  }

  Future<Uint8List> exportBooksToPdf() async {
    try {
      final response = await _dio.get(
        '/book/export/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Gagal mengekspor data PDF.');
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

  Future<UserResponse> getMembers({int page = 1}) async {
    try {
      // Menggunakan endpoint yang benar dari file routes/api.php Anda
      final response = await _dio.get('/user/member/all', queryParameters: {'page': page});
      final responseData = response.data;
      
      // Berdasarkan UserController, path datanya adalah 'data' -> 'users'
      if (responseData is Map<String, dynamic> &&
          responseData['data']['users'] is Map<String, dynamic> &&
          responseData['data']['users']['data'] is List) {
            
        final userData = responseData['data']['users'];
        final List<dynamic> userListJson = userData['data'];
        
        final List<User> users = userListJson.map((json) => User.fromJson(json)).toList();
        
        return UserResponse(
          users: users,
          currentPage: userData['current_page'],
          lastPage: userData['last_page'],
        );
      } else {
        throw Exception('Struktur data member tidak terduga.');
      }
    } catch (e) {
      throw Exception('Gagal memuat data member.');
    }
  }

  Future<PeminjamanResponse> getPeminjamanList({int page = 1}) async {
    try {
      final response = await _dio.get('/peminjaman/all', queryParameters: {'page': page});
      final responseData = response.data;

      // PERBAIKAN: Berdasarkan PeminjamanController, path yang benar adalah 'data' -> 'peminjaman'
      // dan objek 'peminjaman' ini adalah objek pagination itu sendiri.
      if (responseData is Map &&
          responseData['data'] is Map &&
          responseData['data']['peminjaman'] is Map &&
          responseData['data']['peminjaman']['data'] is List) {

        // Ambil objek pagination dari 'peminjaman'
        final peminjamanData = responseData['data']['peminjaman'];
        final List peminjamanListJson = peminjamanData['data'];

        final List<Peminjaman> list = peminjamanListJson.map((json) => Peminjaman.fromJson(json)).toList();

        final bool hasMore = peminjamanData['current_page'] < peminjamanData['last_page'];

        return PeminjamanResponse(peminjamanList: list, hasMore: hasMore);
      } else {
        throw Exception('Struktur data peminjaman dari API tidak terduga.');
      }
    } catch (e) {
      throw Exception('Gagal memuat riwayat peminjaman.');
    }
  }
}