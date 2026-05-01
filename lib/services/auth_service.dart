import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/api_config.dart';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userEmailKey = 'userEmail';
  static const String _userNameKey = 'userName';
  static const String _userIdKey = 'userId';

  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  static String get baseUrl {
    return ApiConfig.getBaseUrl();
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userEmailKey, email);
        await prefs.setString(_userNameKey, data['name']);
        await prefs.setInt(_userIdKey, data['user_id']);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Login error: $e");
      return false;
    }
  }

  static Future<bool> signInWithGoogle() async {
    try {
      debugPrint("AuthService: Starting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint("AuthService: Google Sign-In aborted by user or popup closed prematurely.");
        return false;
      }

      debugPrint("AuthService: Google Sign-In successful for ${googleUser.email}");
      debugPrint("AuthService: Sending data to backend: $baseUrl/google-login");

      final response = await http.post(
        Uri.parse('$baseUrl/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': googleUser.email,
          'name': googleUser.displayName,
          'id': googleUser.id,
          'photoUrl': googleUser.photoUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint("AuthService: Backend response status: ${response.statusCode}");
      debugPrint("AuthService: Backend response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userEmailKey, googleUser.email);
        await prefs.setString(_userNameKey, googleUser.displayName ?? 'Google User');
        await prefs.setInt(_userIdKey, data['user_id']);
        debugPrint("AuthService: session saved successfully");
        return true;
      }
      return false;
    } catch (e, stack) {
      debugPrint("AuthService: Google Sign-In ERROR: $e");
      debugPrint("AuthService: Stack trace: $stack");
      return false;
    }
  }

  static Future<bool> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Signup error: $e");
      return false;
    }
  }

  static Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Request Password Reset error: $e");
      return false;
    }
  }

  static Future<bool> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
          'new_password': newPassword
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Reset Password error: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
  }

  static Future<Map<String, dynamic>?> getProfile(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profile/$userId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("Get profile error: $e");
      return null;
    }
  }

  static Future<bool> updateProfile(int userId, String name, String email) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userNameKey, name);
        await prefs.setString(_userEmailKey, email);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Update profile error: $e");
      return false;
    }
  }

  static Future<bool> deleteAccount(int userId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/profile/$userId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Delete account error: $e");
      return false;
    }
  }

  // Dog Profile Sync Methods
  static Future<int?> syncDog(Map<String, dynamic> dogData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/dogs'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dogData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      }
      return null;
    } catch (e) {
      debugPrint("Sync dog error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDogs(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/dogs/$userId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint("Fetch dogs error: $e");
      return [];
    }
  }

  static Future<bool> syncUpdateDog(int dogId, Map<String, dynamic> dogData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/dogs/$dogId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dogData),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Update dog sync error: $e");
      return false;
    }
  }

  static Future<bool> syncDeleteDog(int dogId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/dogs/$dogId'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete dog sync error: $e");
      return false;
    }
  }
}
