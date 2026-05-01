import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String getBaseUrl() {
    if (kIsWeb) {
      return dotenv.env['BACKEND_URL_WEB'] ?? 'http://127.0.0.1:8001';
    } else if (Platform.isAndroid) {
      return dotenv.env['BACKEND_URL_ANDROID'] ?? 'http://10.0.2.2:8001';
    } else {
      // Fallback for iOS or other platforms
      return dotenv.env['BACKEND_URL_WEB'] ?? 'http://127.0.0.1:8001';
    }
  }
}
