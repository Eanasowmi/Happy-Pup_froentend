import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:io' show Platform;
import 'app/app_theme.dart';
import 'app/app_routes.dart';
import 'services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables based on release mode
  if (kReleaseMode) {
    await dotenv.load(fileName: ".env.production");
  } else {
    await dotenv.load(fileName: ".env.local");
  }
  
  if (kIsWeb) {
    // Must initialize web db factory BEFORE any DB calls
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  final bool loggedIn = await AuthService.isLoggedIn();
  
  runApp(UnderstandingDogsApp(isLoggedIn: loggedIn));
}

class UnderstandingDogsApp extends StatelessWidget {
  final bool isLoggedIn;
  const UnderstandingDogsApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Happy Pup',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: isLoggedIn ? AppRoutes.dashboard : AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
