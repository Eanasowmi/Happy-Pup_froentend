import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String getBaseUrl() {
    if (kIsWeb) {
      const url = String.fromEnvironment('BACKEND_URL_WEB', defaultValue: 'http://127.0.0.1:8001');
      return url;
    } else if (Platform.isAndroid) {
      const url = String.fromEnvironment('BACKEND_URL_ANDROID', defaultValue: 'http://10.0.2.2:8001');
      return url;
    } else {
      // Fallback for iOS or other platforms
      const url = String.fromEnvironment('BACKEND_URL_WEB', defaultValue: 'http://127.0.0.1:8001');
      return url;
    }
  }
}
