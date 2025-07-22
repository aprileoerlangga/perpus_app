import 'package:dio/dio.dart';
import 'dart:io';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/book_response.dart';
import 'package:perpus_app/models/category.dart' as category_model;
import 'package:perpus_app/models/peminjaman.dart';
import 'package:perpus_app/models/peminjaman_response.dart';
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/user_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  final Dio _dio;

  ApiService._()
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://perpus-api.mamorasoft.com/api',
          connectTimeout: const Duration(milliseconds: 15000), // Increased timeout
          receiveTimeout: const Duration(milliseconds: 15000), // Increased timeout
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
        onError: (error, handler) {
          // Enhanced error logging
          print('DioError: ${error.type}');
          print('Response: ${error.response?.data}');
          print('Status Code: ${error.response?.statusCode}');
          return handler.next(error);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  // Helper method for retry with exponential backoff
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation,
    {int maxRetries = 3, Duration initialDelay = const Duration(seconds: 1)}
  ) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } on DioException catch (e) {
        attempt++;
        
        // Check if it's a rate limit error (429)
        if (e.response?.statusCode == 429) {
          if (attempt >= maxRetries) {
            print('❌ Max retries reached for rate limit. Giving up.');
            rethrow;
          }
          
          print('⏳ Rate limit hit (429). Waiting ${delay.inSeconds}s before retry $attempt/$maxRetries');
          await Future.delayed(delay);
          delay = delay * 2; // Exponential backoff
          continue;
        } else {
          // For non-rate-limit errors, don't retry
          rethrow;
        }
      }
    }
    
    throw Exception('Max retries exceeded');
  }

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
      final response = await _dio.post('/login', data: {
        'username': username, 
        'password': password
      });
      
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
    } on DioException catch (e) {
      print('Login error: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Koneksi timeout. Periksa jaringan internet Anda.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Username atau password salah.');
      }
      throw Exception('Login gagal. Silakan coba lagi.');
    } catch (e) {
      print('Unexpected login error: $e');
      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  Future<bool> register(String name, String username, String email, String password, String confirmPassword) async {
    try {
      final response = await _dio.post('/register',
        data: {
          'name': name, 
          'username': username, 
          'email': email,
          'password': password, 
          'confirm_password': confirmPassword,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Register error: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Koneksi timeout. Periksa jaringan internet Anda.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
      } else if (e.response?.statusCode == 422) {
        // Extract specific validation errors
        final errors = e.response?.data['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          String errorMessage = 'Validasi gagal:\n';
          errors.forEach((field, messages) {
            if (messages is List) {
              errorMessage += '• ${messages.join(', ')}\n';
            }
          });
          throw Exception(errorMessage);
        } else {
          throw Exception('Data yang dimasukkan tidak valid.');
        }
      }
      throw Exception('Registrasi gagal. Silakan coba lagi.');
    } catch (e) {
      print('Unexpected register error: $e');
      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  // --- BOOK CRUD ---
  Future<bool> addBook(Map<String, String> bookData, [File? imageFile, XFile? webImageFile]) async {
    return await _retryWithBackoff(() async {
      try {
        print('📤 Adding book: ${bookData['judul']}');
        print('📷 Native Image file: ${imageFile?.path}');
        print('📷 Web Image file: ${webImageFile?.path}');
        
        FormData formData = FormData.fromMap(bookData);
        
        // Handle native platform image (mobile/desktop)
        if (imageFile != null) {
          String fileName = imageFile.path.split('/').last;
          formData.files.add(MapEntry(
            'image',
            await MultipartFile.fromFile(imageFile.path, filename: fileName),
          ));
          print('📤 Native image added to form: $fileName');
        }
        // Handle web platform image
        else if (webImageFile != null) {
          final bytes = await webImageFile.readAsBytes();
          String fileName = webImageFile.name;
          
          // Ensure proper MIME type and filename for better server compatibility
          String mimeType = 'image/jpeg';
          if (fileName.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
          }
          
          formData.files.add(MapEntry(
            'image',
            MultipartFile.fromBytes(
              bytes, 
              filename: fileName,
              contentType: MediaType.parse(mimeType),
            ),
          ));
          print('📤 Web image added to form: $fileName (${bytes.length} bytes, $mimeType)');
        }
        
        final response = await _dio.post('/book/create', data: formData);
        print('📥 Add book response: ${response.statusCode}');
        print('📥 Add book data: ${response.data}');
        
        // Debug: Print detailed response for book creation
        if (response.data != null && response.data is Map<String, dynamic>) {
          final data = response.data;
          print('📋 Response keys: ${data.keys}');
          
          if (data['data'] != null && data['data']['book'] != null) {
            final bookData = data['data']['book'];
            print('📖 Created book data: $bookData');
            print('📷 Book path in response: ${bookData['path']}');
          }
        }
        
        return response.statusCode == 201 || response.statusCode == 200;
      } on DioException catch (e) {
        print('❌ Error adding book: ${e.response?.data}');
        print('❌ Error status: ${e.response?.statusCode}');
        
        // Re-throw for retry mechanism if it's a rate limit error
        if (e.response?.statusCode == 429) {
          throw e;
        }
        
        // Enhanced error handling with specific messages
        if (e.response?.statusCode == 500) {
          throw Exception('Server error: Masalah pada server backend. Silakan hubungi administrator.');
        } else if (e.response?.statusCode == 422) {
          final errors = e.response?.data;
          if (errors != null && errors['errors'] is Map) {
            final errorMessages = (errors['errors'] as Map).values.expand((e) => e).join(', ');
            throw Exception('Validation error: $errorMessages');
          }
          throw Exception('Data tidak valid. Periksa semua field yang diisi.');
        } else if (e.response?.statusCode == 413) {
          throw Exception('File terlalu besar. Pilih gambar dengan ukuran lebih kecil.');
        }
        
        return false;
      }
    });
  }
  
  Future<bool> updateBook(int id, Map<String, String> bookData, [File? imageFile, XFile? webImageFile]) async {
    return await _retryWithBackoff(() async {
      try {
        print('📤 Updating book: ${bookData['judul']}');
        print('📷 Native Image file: ${imageFile?.path}');
        print('📷 Web Image file: ${webImageFile?.path}');
        
        FormData formData = FormData.fromMap(bookData);
        
        // Handle native platform image (mobile/desktop)
        if (imageFile != null) {
          String fileName = imageFile.path.split('/').last;
          formData.files.add(MapEntry(
            'image',
            await MultipartFile.fromFile(imageFile.path, filename: fileName),
          ));
          print('📤 Native image added to form: $fileName');
        }
        // Handle web platform image
        else if (webImageFile != null) {
          final bytes = await webImageFile.readAsBytes();
          String fileName = webImageFile.name;
          
          // Ensure proper MIME type and filename for better server compatibility
          String mimeType = 'image/jpeg';
          if (fileName.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
          }
          
          formData.files.add(MapEntry(
            'image',
            MultipartFile.fromBytes(
              bytes, 
              filename: fileName,
              contentType: MediaType.parse(mimeType),
            ),
          ));
          print('📤 Web image added to form: $fileName (${bytes.length} bytes, $mimeType)');
        }
        
        final response = await _dio.post('/book/$id/update', data: formData);
        return response.statusCode == 200;
      } on DioException catch (e) {
        print('Error updating book: ${e.response?.data}');
        
        // Re-throw for retry mechanism if it's a rate limit error
        if (e.response?.statusCode == 429) {
          throw e;
        }
        
        // Enhanced error handling with specific messages
        if (e.response?.statusCode == 500) {
          throw Exception('Server error: Masalah pada server backend. Silakan hubungi administrator.');
        } else if (e.response?.statusCode == 422) {
          final errors = e.response?.data;
          if (errors != null && errors['errors'] is Map) {
            final errorMessages = (errors['errors'] as Map).values.expand((e) => e).join(', ');
            throw Exception('Validation error: $errorMessages');
          }
          throw Exception('Data tidak valid. Periksa semua field yang diisi.');
        } else if (e.response?.statusCode == 413) {
          throw Exception('File terlalu besar. Pilih gambar dengan ukuran lebih kecil.');
        }
        
        return false;
      }
    });
  }

  Future<bool> deleteBook(int id) async {
    try {
      final response = await _dio.delete('/book/$id/delete');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Bulk import books
  Future<Map<String, dynamic>> bulkImportBooks(List<Map<String, dynamic>> booksData) async {
    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (var bookData in booksData) {
        try {
          final response = await _dio.post('/book/create', data: bookData);
          
          if (response.statusCode == 201 || response.statusCode == 200) {
            successCount++;
            print('✅ Book "${bookData['judul']}" imported successfully');
          } else {
            failCount++;
            errors.add('Gagal menambah buku: ${bookData['judul']} (Status: ${response.statusCode})');
          }
        } catch (e) {
          failCount++;
          if (e is DioException) {
            errors.add('Error pada buku "${bookData['judul']}": ${e.response?.data ?? e.message}');
          } else {
            errors.add('Error pada buku "${bookData['judul']}": ${e.toString()}');
          }
        }
      }

      return {
        'success': true,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'total': booksData.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'successCount': 0,
        'failCount': booksData.length,
        'total': booksData.length,
      };
    }
  }

  Future<BookResponse> getBooks({int page = 1, String? query, int? categoryId}) async {
    return await _retryWithBackoff(() async {
      try {
        String endpoint;
        Map<String, dynamic> queryParameters = {'page': page};
        
        // Choose the correct endpoint based on whether we're filtering by category
        if (categoryId != null) {
          // Use the specific category filter endpoint
          endpoint = '/category/$categoryId/book/all';
        } else {
          // Use the general books endpoint
          endpoint = '/book/all';
        }
        
        // Add search query if provided
        if (query != null && query.isNotEmpty) {
          queryParameters['search'] = query;
        }

        final response = await _dio.get(endpoint, queryParameters: queryParameters);
        final responseData = response.data;

        // ==================== LOGIKA PARSING FLEKSIBEL ====================
        if (responseData is Map<String, dynamic> && responseData['data'] != null) {
        final data = responseData['data'];
        
        // Cek 1: Apakah responsnya berhalaman (paginated)?
        if (data['books'] is Map<String, dynamic> && data['books']['data'] is List) {
          final bookData = data['books'];
          final List<dynamic> bookListJson = bookData['data'];
          print('📚 Parsing paginated books: ${bookListJson.length} items');
          
          // Debug: Print path for each book
          for (int i = 0; i < bookListJson.length && i < 3; i++) {
            final book = bookListJson[i];
            print('📖 Book ${i + 1}: "${book['judul']}" - path: "${book['path']}"');
          }
          
          final List<Book> books = bookListJson.map((json) => Book.fromJson(json)).toList();
          final bool hasMore = bookData['current_page'] < bookData['last_page'];
          return BookResponse(books: books, hasMore: hasMore);
        }
        
        // Cek 2: Apakah responsnya adalah daftar sederhana (simple list)?
        else if (data['books'] is List) {
          final List<dynamic> bookListJson = data['books'];
          print('📚 Parsing simple books list: ${bookListJson.length} items');
          
          // Debug: Print path for each book
          for (int i = 0; i < bookListJson.length && i < 3; i++) {
            final book = bookListJson[i];
            print('📖 Book ${i + 1}: "${book['judul']}" - path: "${book['path']}"');
          }
          
          final List<Book> books = bookListJson.map((json) => Book.fromJson(json)).toList();
          // Jika ini adalah daftar sederhana, kita anggap tidak ada halaman lagi
          return BookResponse(books: books, hasMore: false);
        }
        
        // Cek 3: Untuk endpoint category/{id}/book/all, mungkin struktur berbeda
        else if (data is List) {
          final List<dynamic> bookListJson = data;
          print('📚 Parsing direct list: ${bookListJson.length} items');
          
          // Debug: Print path for each book
          for (int i = 0; i < bookListJson.length && i < 3; i++) {
            final book = bookListJson[i];
            print('📖 Book ${i + 1}: "${book['judul']}" - path: "${book['path']}"');
          }
          
          final List<Book> books = bookListJson.map((json) => Book.fromJson(json)).toList();
          return BookResponse(books: books, hasMore: false);
        }
      }
      
      // Jika tidak ada format yang cocok, kembalikan list kosong
      return BookResponse(books: [], hasMore: false);
      // ================================================================

    } catch (e) {
      print('Error in getBooks: $e');
      throw Exception('Gagal mengambil data buku: ${e.toString()}');
    }
    });
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

  Future<List<category_model.Category>> getCategories({String? query}) async {
    return await _retryWithBackoff(() async {
      try {
        final Map<String, dynamic> queryParameters = {};
        if (query != null && query.isNotEmpty) {
          queryParameters['search'] = query;
        }
        
        final response = await _dio.get('/category/all/all', queryParameters: queryParameters);
        final responseData = response.data;
        
        // Enhanced parsing to handle different response structures
        if (responseData is Map<String, dynamic>) {
          List<dynamic>? categoryList;
          
          // Check different possible structures
          if (responseData['data'] is Map<String, dynamic> && 
              responseData['data']['categories'] is List) {
            categoryList = responseData['data']['categories'];
          } else if (responseData['data'] is List) {
            categoryList = responseData['data'];
          } else if (responseData['categories'] is List) {
            categoryList = responseData['categories'];
          }
          
          if (categoryList != null) {
            return categoryList.map((json) => category_model.Category.fromJson(json)).toList();
          }
        }
        
        return [];
      } catch (e) {
        print('Error loading categories: $e');
        throw Exception('Gagal memuat kategori.');
      }
    });
  }

  // New method to get books by specific category using the correct API endpoint
  Future<List<Book>> getBooksByCategory(int categoryId) async {
    return await _retryWithBackoff(() async {
      try {
        final response = await _dio.get('/category/$categoryId/book/all');
        final responseData = response.data;
        
        if (responseData is Map<String, dynamic>) {
          List<dynamic>? bookList;
          
          // Check different possible structures
          if (responseData['data'] is Map<String, dynamic> && 
              responseData['data']['books'] is List) {
            bookList = responseData['data']['books'];
          } else if (responseData['data'] is List) {
            bookList = responseData['data'];
          } else if (responseData['books'] is List) {
            bookList = responseData['books'];
          }
          
          if (bookList != null) {
            return bookList.map((json) => Book.fromJson(json)).toList();
          }
        }
        
        return [];
      } catch (e) {
        print('Error loading books by category: $e');
        throw Exception('Gagal memuat buku berdasarkan kategori.');
      }
    });
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

  Future<UserResponse> getMembers({int page = 1, String? query, int perPage = 10}) async {
    try {
      // Siapkan parameter untuk dikirim ke API
      final Map<String, dynamic> queryParameters = {
        'page': page,
        'per_page': perPage, // Tambahkan parameter per_page
      };
      // Jika ada query pencarian, tambahkan ke parameter
      if (query != null && query.isNotEmpty) {
        queryParameters['search'] = query;
        print('Searching members with query: $query');
      }
      
      print('API Request: /user/member/all with params: $queryParameters');
      
      final response = await _dio.get('/user/member/all', queryParameters: queryParameters);
      
      print('API Response status: ${response.statusCode}');
      print('API Response data keys: ${response.data.keys}');
      
      final data = response.data['data'];
      final List<dynamic> userList = data['users']['data'];
      final users = userList.map((user) => User.fromJson(user)).toList();

      print('Parsed ${users.length} users from API response');

      return UserResponse(
        users: users,
        currentPage: data['users']['current_page'],
        lastPage: data['users']['last_page'],
      );
    } catch (e) {
      print('Error in getMembers: $e');
      throw Exception('Gagal mengambil data member.');
    }
  }

  // Helper function to parse date with multiple formats
  DateTime? _parseFlexibleDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    
    try {
      // Try standard ISO format first (yyyy-MM-dd)
      return DateTime.parse(dateString);
    } catch (e) {
      try {
        // Try parsing formats like "Dec 22, 2023"
        final months = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        
        final parts = dateString.trim().split(RegExp(r'[,\s]+'));
        if (parts.length == 3) {
          final monthName = parts[0];
          final day = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          
          if (months.containsKey(monthName) && day != null && year != null) {
            return DateTime(year, months[monthName]!, day);
          }
        }
      } catch (e2) {
        print('⚠️ Failed to parse date: "$dateString" - $e2');
      }
    }
    
    print('⚠️ Unable to parse date format: "$dateString"');
    return null;
  }

  Future<PeminjamanResponse> getPeminjamanList({
    int page = 1, 
    String? searchQuery, 
    String? filterMonth, 
    String? filterYear,
    String? startDate,
    String? endDate
  }) async {
    try {
      print('🚀 === getPeminjamanList Called ===');
      print('Parameters: page=$page, search="$searchQuery", month="$filterMonth", year="$filterYear", startDate="$startDate", endDate="$endDate"');

      // Siapkan parameter query - mulai dengan parameter dasar saja
      final Map<String, dynamic> queryParameters = {
        'page': page,
      };

      // UNTUK SEMENTARA, KITA TIDAK KIRIM FILTER KE API DULU
      // Karena API mungkin belum mendukung, kita lakukan semua filtering di client side
      print('🚀 API Request: /peminjaman/all with params: $queryParameters');

      final response = await _dio.get('/peminjaman/all', queryParameters: queryParameters);
      final responseData = response.data;

      print('✅ API Response status: ${response.statusCode}');

      // PERBAIKAN: Sesuaikan dengan struktur JSON yang sebenarnya
      if (responseData is Map &&
          responseData['data'] is Map &&
          responseData['data']['peminjaman'] is List) {

        // Langsung ambil list dari 'peminjaman'
        final List<dynamic> peminjamanListJson = responseData['data']['peminjaman'];
        print('📊 Total peminjaman from API: ${peminjamanListJson.length}');

        final List<Peminjaman> allPeminjaman = peminjamanListJson
            .map((json) => Peminjaman.fromJson(json as Map<String, dynamic>))
            .toList();

        print('📋 Original list: ${allPeminjaman.length} peminjaman');

        // MULAI FILTERING DI CLIENT SIDE
        List<Peminjaman> filteredList = allPeminjaman;

        // 1. FILTER BERDASARKAN SEARCH QUERY
        if (searchQuery != null && searchQuery.isNotEmpty) {
          print('🔍 Applying search filter: "$searchQuery"');
          filteredList = filteredList.where((peminjaman) {
            final userName = peminjaman.user.name.toLowerCase();
            final bookTitle = peminjaman.book.judul.toLowerCase();
            final query = searchQuery.toLowerCase();
            
            final userMatch = userName.contains(query);
            final bookMatch = bookTitle.contains(query);
            final matches = userMatch || bookMatch;
            
            if (matches) {
              print('✅ MATCH - Peminjaman ${peminjaman.id}: User "$userName" or Book "$bookTitle" contains "$query"');
            }
            
            return matches;
          }).toList();
          print('🔍 After search filter: ${filteredList.length} peminjaman');
        }

        // 2. FILTER BERDASARKAN BULAN
        if (filterMonth != null && filterMonth.isNotEmpty) {
          print('📅 Applying month filter: "$filterMonth"');
          final targetMonth = int.tryParse(filterMonth);
          if (targetMonth != null && targetMonth >= 1 && targetMonth <= 12) {
            filteredList = filteredList.where((peminjaman) {
              try {
                final tanggalPinjam = _parseFlexibleDate(peminjaman.tanggalPinjam);
                if (tanggalPinjam == null) {
                  print('⚠️ Could not parse date: ${peminjaman.tanggalPinjam}');
                  return false;
                }
                final matches = tanggalPinjam.month == targetMonth;
                
                if (matches) {
                  print('✅ MONTH MATCH - Peminjaman ${peminjaman.id}: Date ${peminjaman.tanggalPinjam} (month ${tanggalPinjam.month}) == $targetMonth');
                }
                
                return matches;
              } catch (e) {
                print('⚠️ Error parsing date for peminjaman ${peminjaman.id}: ${peminjaman.tanggalPinjam} - $e');
                return false;
              }
            }).toList();
            print('📅 After month filter: ${filteredList.length} peminjaman');
          } else {
            print('⚠️ Invalid month value: "$filterMonth"');
          }
        }

        // 3. FILTER BERDASARKAN TAHUN
        if (filterYear != null && filterYear.isNotEmpty) {
          print('📅 Applying year filter: "$filterYear"');
          final targetYear = int.tryParse(filterYear);
          if (targetYear != null) {
            filteredList = filteredList.where((peminjaman) {
              try {
                final tanggalPinjam = _parseFlexibleDate(peminjaman.tanggalPinjam);
                if (tanggalPinjam == null) {
                  print('⚠️ Could not parse date: ${peminjaman.tanggalPinjam}');
                  return false;
                }
                final matches = tanggalPinjam.year == targetYear;
                
                if (matches) {
                  print('✅ YEAR MATCH - Peminjaman ${peminjaman.id}: Date ${peminjaman.tanggalPinjam} (year ${tanggalPinjam.year}) == $targetYear');
                }
                
                return matches;
              } catch (e) {
                print('⚠️ Error parsing date for peminjaman ${peminjaman.id}: ${peminjaman.tanggalPinjam} - $e');
                return false;
              }
            }).toList();
            print('📅 After year filter: ${filteredList.length} peminjaman');
          } else {
            print('⚠️ Invalid year value: "$filterYear"');
          }
        }

        // 4. FILTER BERDASARKAN RENTANG TANGGAL
        if ((startDate != null && startDate.isNotEmpty) || 
            (endDate != null && endDate.isNotEmpty)) {
          print('📅 Applying date range filter: "$startDate" to "$endDate"');
          filteredList = filteredList.where((peminjaman) {
            try {
              final tanggalPinjam = _parseFlexibleDate(peminjaman.tanggalPinjam);
              if (tanggalPinjam == null) {
                print('⚠️ Could not parse date: ${peminjaman.tanggalPinjam}');
                return false;
              }
              
              bool startMatch = true;
              bool endMatch = true;
              
              if (startDate != null && startDate.isNotEmpty) {
                final start = _parseFlexibleDate(startDate);
                if (start != null) {
                  startMatch = tanggalPinjam.isAfter(start) || tanggalPinjam.isAtSameMomentAs(start);
                }
              }
              
              if (endDate != null && endDate.isNotEmpty) {
                final end = _parseFlexibleDate(endDate);
                if (end != null) {
                  endMatch = tanggalPinjam.isBefore(end.add(Duration(days: 1)));
                }
              }
              
              final matches = startMatch && endMatch;
              
              if (matches) {
                print('✅ DATE RANGE MATCH - Peminjaman ${peminjaman.id}: Date ${peminjaman.tanggalPinjam} in range $startDate - $endDate');
              }
              
              return matches;
            } catch (e) {
              print('⚠️ Error parsing date for peminjaman ${peminjaman.id}: ${peminjaman.tanggalPinjam} - $e');
              return false;
            }
          }).toList();
          print('📅 After date range filter: ${filteredList.length} peminjaman');
        }

        print('🎯 === FINAL RESULT ===');
        print('Original: ${allPeminjaman.length} peminjaman');
        print('Filtered: ${filteredList.length} peminjaman');
        print('=======================');

        // Pagination logic
        final bool hasMore = filteredList.length >= 10;

        return PeminjamanResponse(peminjamanList: filteredList, hasMore: hasMore);
      } else {
        // Jika struktur tidak sesuai, lempar error
        print('❌ Unexpected API response structure');
        print('Response type: ${responseData.runtimeType}');
        if (responseData is Map) {
          print('Response keys: ${responseData.keys}');
        }
        throw Exception('Struktur data peminjaman dari API tidak terduga.');
      }
    } on DioException catch (e) {
      // Menangani error dari Dio dengan lebih baik
      print('❌ DioException in getPeminjamanList: ${e.response?.data}');
      throw Exception('Gagal memuat riwayat peminjaman. Error: ${e.message}');
    } catch (e) {
      print('❌ General error in getPeminjamanList: $e');
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
      print('Creating peminjaman: book=$bookId, member=$memberId, tanggal_pinjam=$tanggalPinjam, tanggal_kembali=$tanggalKembali');
      
      final response = await _dio.post(
        '/peminjaman/book/$bookId/member/$memberId',
        data: {
          'tanggal_peminjaman': tanggalPinjam,
          'tanggal_pengembalian': tanggalKembali,
        },
      );
      
      print('Create peminjaman API response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Gagal membuat peminjaman: $e');
      return false;
    }
  }

  // FUNGSI BARU UNTUK MENGEMBALIKAN BUKU (MEMBER)
  Future<bool> returnBook(int peminjamanId) async {
    try {
      // Gunakan POST method yang benar untuk endpoint '/return'
      // Backend akan mengubah status menjadi 3 (dikembalikan)
      final response = await _dio.post('/peminjaman/book/$peminjamanId/return');
      
      print('Return book API response: ${response.statusCode}');
      print('Return book API response data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('Gagal mengembalikan buku: $e');
      return false;
    }
  }

  // FUNGSI UNTUK ADMIN APPROVE PEMINJAMAN
  Future<bool> acceptPeminjaman(int peminjamanId) async {
    try {
      // Endpoint '/accept' untuk admin approve/accept peminjaman menggunakan POST
      final response = await _dio.post('/peminjaman/book/$peminjamanId/accept');
      
      print('Accept peminjaman API response: ${response.statusCode}');
      print('Accept peminjaman API response data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('Gagal approve peminjaman: $e');
      return false;
    }
  }

  // FUNGSI UNTUK MENDAPATKAN DETAIL PEMINJAMAN
  Future<Map<String, dynamic>?> getPeminjamanDetail(int peminjamanId) async {
    try {
      final response = await _dio.get('/peminjaman/$peminjamanId');
      
      if (response.statusCode == 200) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Gagal mendapatkan detail peminjaman: $e');
      return null;
    }
  }

  // FUNGSI UNTUK MENDAPATKAN RIWAYAT PEMINJAMAN MILIK MEMBER
  Future<PeminjamanResponse> getMyPeminjamanList({int page = 1, String? query}) async {
    // 1. Dapatkan ID user yang sedang login
    final memberId = await getUserId();
    print('=== MY PEMINJAMAN REQUEST ===');
    print('Member ID: $memberId');
    
    if (memberId == null) {
      print('Member ID is null, returning empty list');
      return PeminjamanResponse(peminjamanList: [], hasMore: false);
    }
    
    try {
      // 2. Gunakan endpoint `/peminjaman/all` karena tidak ada endpoint user-specific
      final Map<String, dynamic> queryParameters = {
        'page': page,
      };
      
      // Tambahkan query pencarian jika ada
      if (query != null && query.isNotEmpty) {
        queryParameters['search'] = query;
      }
      
      // Gunakan endpoint yang tersedia: /peminjaman/all
      final response = await _dio.get('/peminjaman/all', queryParameters: queryParameters);
      final responseData = response.data;

      print('API Response: ${response.statusCode}');

      // PERBAIKAN: Sesuaikan dengan struktur JSON yang sebenarnya
      if (responseData is Map &&
          responseData['data'] is Map &&
          responseData['data']['peminjaman'] is List) {

        // Ambil semua data peminjaman
        final List<dynamic> allPeminjamanJson = responseData['data']['peminjaman'];
        print('Total peminjaman from API: ${allPeminjamanJson.length}');

        // Konversi ke objek Peminjaman
        final List<Peminjaman> allPeminjaman = allPeminjamanJson
            .map((json) => Peminjaman.fromJson(json as Map<String, dynamic>))
            .toList();

        // FILTER: Hanya ambil data peminjaman milik member yang login
        final List<Peminjaman> myPeminjaman = allPeminjaman
            .where((peminjaman) {
              bool matches = peminjaman.user.id == memberId;
              print('Peminjaman ID ${peminjaman.id}: User ${peminjaman.user.name} (ID: ${peminjaman.user.id}) == $memberId? $matches');
              return matches;
            })
            .toList();

        print('✅ Found ${myPeminjaman.length} peminjaman for member $memberId (filtered from ${allPeminjaman.length} total)');

        // Untuk pagination, karena kita filter di client side, kita tidak bisa mengandalkan pagination server
        // Jadi kita set hasMore = false untuk sementara
        return PeminjamanResponse(peminjamanList: myPeminjaman, hasMore: false);

      } else {
        print('❌ Unexpected API response structure');
        print('Response data type: ${responseData.runtimeType}');
        if (responseData is Map) {
          print('Response keys: ${responseData.keys}');
        }
        return PeminjamanResponse(peminjamanList: [], hasMore: false);
      }

    } catch (e) {
      print("❌ Error in getMyPeminjamanList: $e");
      if (e is DioException) {
        print('DioException details: ${e.response?.data}');
      }
      throw Exception('Gagal memuat riwayat peminjaman.');
    }
  }
}