import 'package:flutter/material.dart';

class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Exception) return error.toString().replaceAll('Exception: ', '');
    
    final errorStr = error.toString();
    
    if (errorStr.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    if (errorStr.contains('Connection refused')) {
      return 'Cannot connect to server. Please check if server is running.';
    }
    if (errorStr.contains('401') || errorStr.contains('403')) {
      return 'Invalid credentials. Please try again.';
    }
    if (errorStr.contains('404')) {
      return 'Resource not found. Please try again later.';
    }
    if (errorStr.contains('500')) {
      return 'Server error. Please try again later.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request timeout. Please check your connection.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
  
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}