import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../models/saved_route.dart';

class RouteRepository {
  final AppDatabase _database;

  RouteRepository({
    AppDatabase? database,
  }) : _database =
            database ?? AppDatabase();

  Future<Database> get _db async {
    return _database.database;
  }

  Future<int> saveRoute(
    SavedRoute route,
  ) async {
    final database = await _db;

    return database.insert(
      'saved_routes',
      route.toMap()
        ..remove('id'),
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );
  }

  Future<List<SavedRoute>>
      getSavedRoutes() async {
    final database = await _db;

    final rows =
        await database.query(
      'saved_routes',
      orderBy:
          'created_at DESC',
    );

    return rows
        .map(
          SavedRoute.fromMap,
        )
        .toList();
  }

  Future<void> deleteRoute(
    int routeId,
  ) async {
    final database = await _db;

    await database.delete(
      'route_points',
      where:
          'route_id = ?',
      whereArgs: [
        routeId,
      ],
    );

    await database.delete(
      'saved_routes',
      where:
          'id = ?',
      whereArgs: [
        routeId,
      ],
    );
  }

  Future<void> saveRoutePoint({
    required int routeId,
    required double latitude,
    required double longitude,
    required int sequence,
  }) async {
    final database = await _db;

    await database.insert(
      'route_points',
      {
        'route_id': routeId,
        'latitude': latitude,
        'longitude': longitude,
        'sequence': sequence,
      },
    );
  }

  Future<List<Map<String, dynamic>>>
      getRoutePoints(
    int routeId,
  ) async {
    final database = await _db;

    return database.query(
      'route_points',
      where:
          'route_id = ?',
      whereArgs: [
        routeId,
      ],
      orderBy:
          'sequence ASC',
    );
  }
}