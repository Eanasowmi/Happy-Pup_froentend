import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    
    if (kIsWeb) {
      // Factory already set in main.dart via databaseFactoryFfiWeb
      path = 'dog_tracker.db';
    } else {
      // Use Application Support directory for stable persistence on desktop
      final Directory appSupportDir = await getApplicationSupportDirectory();
      
      // Ensure directory exists
      if (!await appSupportDir.exists()) {
        await appSupportDir.create(recursive: true);
      }
      
      path = join(appSupportDir.path, 'dog_tracker.db');
      
      // Note: Factory initialization moved to main.dart for cleaner startup
    }

    debugPrint("Opening database at: $path");
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5, // Version increased for additional fields and image_data in history
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    
    // Check record count for debugging
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM dog_growth_history'));
    debugPrint("Database initialized. Current record count: $count");
    
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        breed TEXT,
        age INTEGER,
        age_range TEXT,
        weight REAL,
        image_path TEXT,
        last_skin_disease TEXT,
        last_emotion TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE dog_growth_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dog_id TEXT,
        date TEXT,
        predicted_agerange TEXT,
        health_status TEXT,
        size_score REAL,
        weight REAL,
        image_path TEXT,
        image_data TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dogs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          name TEXT,
          breed TEXT,
          age INTEGER,
          weight REAL,
          image_path TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add new fields for version 3
      try {
        await db.execute('ALTER TABLE dogs ADD COLUMN age_range TEXT');
        await db.execute('ALTER TABLE dogs ADD COLUMN created_at TEXT');
      } catch (e) {
        debugPrint("Error upgrading to version 3: $e");
      }
    }
    if (oldVersion < 4) {
      // Add new fields for version 4 (Skin and Emotion)
      try {
        await db.execute('ALTER TABLE dogs ADD COLUMN last_skin_disease TEXT');
        await db.execute('ALTER TABLE dogs ADD COLUMN last_emotion TEXT');
      } catch (e) {
        debugPrint("Error upgrading to version 4: $e");
      }
    }
    if (oldVersion < 5) {
      // Add image_data to dog_growth_history for version 5
      try {
        await db.execute('ALTER TABLE dog_growth_history ADD COLUMN image_data TEXT');
      } catch (e) {
        debugPrint("Error upgrading to version 5: $e");
      }
    }
  }

  // Dog CRUD Operations
  Future<int> insertDog(Map<String, dynamic> dog) async {
    try {
      final db = await database;
      return await db.insert('dogs', dog);
    } catch (e) {
      debugPrint("Error inserting dog: $e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getDogsByUser(int userId) async {
    try {
      final db = await database;
      return await db.query(
        'dogs',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      debugPrint("Error getting dogs: $e");
      return [];
    }
  }

  Future<int> updateDog(Map<String, dynamic> dog) async {
    try {
      final db = await database;
      return await db.update(
        'dogs',
        dog,
        where: 'id = ?',
        whereArgs: [dog['id']],
      );
    } catch (e) {
      debugPrint("Error updating dog: $e");
      return -1;
    }
  }

  Future<int> deleteDog(int dogId) async {
    try {
      final db = await database;
      return await db.delete(
        'dogs',
        where: 'id = ?',
        whereArgs: [dogId],
      );
    } catch (e) {
      debugPrint("Error deleting dog: $e");
      return 0;
    }
  }

  Future<int> saveDogRecord(Map<String, dynamic> data) async {
    try {
      debugPrint("Saving record for dog: ${data['dog_id']}");
      final db = await database;
      final id = await db.insert('dog_growth_history', data);
      debugPrint("Record saved with ID: $id");
      return id;
    } catch (e) {
      debugPrint("Database Error in saveDogRecord: $e");
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getLastRecord(String dogId) async {
    try {
      final db = await database;
      final results = await db.query(
        'dog_growth_history',
        where: 'dog_id = ?',
        whereArgs: [dogId],
        orderBy: 'id DESC',
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint("Database Error in getLastRecord: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllRecords(String dogId) async {
    try {
      final db = await database;
      return await db.query(
        'dog_growth_history',
        where: 'dog_id = ?',
        whereArgs: [dogId],
        orderBy: 'id DESC',
      );
    } catch (e) {
      debugPrint("Database Error in getAllRecords: $e");
      return [];
    }
  }
  Future<int> deleteRecord(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'dog_growth_history',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint("Record with ID $id deleted. Rows affected: $count");
      return count;
    } catch (e) {
      debugPrint("Database Error in deleteRecord: $e");
      return 0;
    }
  }
}

