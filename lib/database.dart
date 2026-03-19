import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  AppDatabase._();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), "car_maintenance_tracker.db");
    return openDatabase(path, version: 1, onCreate: _createDB, onConfigure: _configureDB);
  }

  static Future<void> _configureDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cars (
        car_uuid TEXT PRIMARY KEY,
        user_id INTEGER,
        name TEXT,
        make TEXT,
        model TEXT,
        year INTEGER,
        vin TEXT,
        mileage INTEGER,
        license_plate TEXT,
        image_path TEXT,
        is_synced INTEGER DEFAULT 0, -- 0 = Not Synced, 1 = Synced
        is_deleted INTEGER DEFAULT 0  -- 0 = Active, 1 = Pending Deletion
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenanceTasks (
        task_uuid TEXT PRIMARY KEY,
        car_uuid TEXT NOT NULL,
        title TEXT,
        category TEXT,
        mileage INTEGER,
        cost REAL,
        scheduled_date INTEGER,
        completed_date INTEGER,
        notes TEXT,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (car_uuid) REFERENCES cars (car_uuid) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> clearUserData() async {
    final db = await database;
    await db.delete("maintenanceTasks");
    await db.delete("cars");
  }
}