import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/api_config.dart';

class ApiService {
  // Use different URLs for web and mobile
  static String get apiUrl {
    return '${ApiConfig.getBaseUrl()}/predict/bcs';
  }

  static Future<Map<String, dynamic>> uploadImage(File? imageFile, {List<int>? webImageBytes, String? webImageName}) async {
    var uri = Uri.parse(apiUrl);
    var request = http.MultipartRequest('POST', uri);

    if (kIsWeb) {
      // For web, use bytes
      if (webImageBytes == null || webImageName == null) {
        throw Exception('No image selected');
      }
      request.files.add(http.MultipartFile.fromBytes('image', webImageBytes, filename: webImageName));
    } else {
      if (imageFile == null) {
        throw Exception('No image selected');
      }
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get prediction');
    }
  }

  static Future<void> savePredictionRecord(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse(apiUrl.replaceAll('/predict/bcs', '/records')),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save record: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPredictionHistory(int userId) async {
    final response = await http.get(
      Uri.parse(apiUrl.replaceAll('/predict/bcs', '/records/$userId')),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch history');
    }
  }

  static Future<void> deleteRecord(int recordId) async {
    final response = await http.delete(
      Uri.parse(apiUrl.replaceAll('/predict/bcs', '/records/$recordId')),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete record: ${response.body}');
    }
  }
}
