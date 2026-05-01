import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

void main() async {
  print('Loading .env.production...');
  await dotenv.load(fileName: ".env.production");
  
  String? webUrl = dotenv.env['BACKEND_URL_WEB'];
  print('Loaded URL: $webUrl');
  
  if (webUrl != null) {
    print('Testing connection to $webUrl/ ...');
    try {
      final response = await http.get(Uri.parse('$webUrl/'));
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('SUCCESS: The environment file works and the deployed backend is reachable!');
      } else {
        print('FAILED: Backend returned a non-200 status code.');
      }
    } catch (e) {
      print('FAILED: Could not connect to backend. Error: $e');
    }
  } else {
    print('FAILED: Could not load URL from environment file.');
  }
}
