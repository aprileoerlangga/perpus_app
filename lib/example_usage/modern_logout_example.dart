// Example Usage of Modern Logout Widgets
// File: lib/example_usage/modern_logout_example.dart

import 'package:flutter/material.dart';
import 'package:perpus_app/widgets/modern_logout_widgets.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/screens/auth/login_screen.dart';

class ModernLogoutExample extends StatelessWidget {
  final ApiService _apiService = ApiService();

  ModernLogoutExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modern Logout Example'),
        actions: [
          // Example 1: Admin Style Logout Button
          ModernLogoutButton(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            ),
            onPressed: () => _showAdminLogout(context),
            text: 'Admin Logout',
          ),
          
          // Example 2: Member Style Logout Button (Icon only)
          ModernLogoutButton(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            onPressed: () => _showMemberLogout(context),
            showText: false,
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Modern Logout Components Example',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Tap the logout buttons in the AppBar to see the dialogs',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ModernLogoutDialog(
        title: 'Admin Logout',
        message: 'Anda akan keluar dari dashboard admin.\nSesi akan berakhir.',
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        ),
        buttonColor: Color(0xFFFF6B6B),
      ),
    );

    if (confirm == true) {
      _performLogout(context, const Color(0xFFFF6B6B));
    }
  }

  Future<void> _showMemberLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ModernLogoutDialog(
        title: 'Member Logout',
        message: 'Anda akan keluar dari dashboard member.\nSampai jumpa lagi!',
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        buttonColor: Color(0xFF667eea),
      ),
    );

    if (confirm == true) {
      _performLogout(context, const Color(0xFF667eea));
    }
  }

  Future<void> _performLogout(BuildContext context, Color progressColor) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModernLoadingDialog(
        message: 'Sedang logout...',
        progressColor: progressColor,
      ),
    );

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      await _apiService.logout();
      
      if (context.mounted) {
        // Navigate to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Usage in different contexts:

class AdminDashboardLogoutExample {
  static Future<void> logout(BuildContext context, ApiService apiService) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ModernLogoutDialog(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        ),
        buttonColor: Color(0xFFFF6B6B),
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ModernLoadingDialog(
          progressColor: Color(0xFFFF6B6B),
        ),
      );

      await apiService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

class MemberDashboardLogoutExample {
  static Future<void> logout(BuildContext context, ApiService apiService) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ModernLogoutDialog(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        buttonColor: Color(0xFF667eea),
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ModernLoadingDialog(
          progressColor: Color(0xFF667eea),
        ),
      );

      await apiService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

// Custom themed logout dialog
class CustomThemedLogoutExample {
  static Future<bool> showCustomLogout(
    BuildContext context, {
    required LinearGradient gradient,
    required Color buttonColor,
    String title = 'Konfirmasi Logout',
    String message = 'Apakah Anda yakin ingin keluar?',
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModernLogoutDialog(
        title: title,
        message: message,
        gradient: gradient,
        buttonColor: buttonColor,
      ),
    );

    return confirm == true;
  }
}
