import 'package:perpus_app/models/user.dart';

class UserResponse {
  final List<User> users;
  final int currentPage;
  final int lastPage;

  UserResponse({
    required this.users,
    required this.currentPage,
    required this.lastPage,
  });
}