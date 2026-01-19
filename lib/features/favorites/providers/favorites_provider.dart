import 'package:flutter/material.dart';
import '../models/favorite_item.dart';
import '../models/favorite_stop.dart';
import '../models/favorite_train.dart';
import '../models/favorite_bus_line.dart';
import '../repositories/favorites_repository.dart';

class FavoritesProvider with ChangeNotifier {
  final FavoritesRepository _repository = FavoritesRepository();

  List<FavoriteItem> _favorites = [];
  bool _isLoading = false;
  String? _error;

  List<FavoriteItem> get favorites => _favorites;
  List<FavoriteStop> get favoriteStops =>
      _favorites.whereType<FavoriteStop>().toList();
  List<FavoriteTrain> get favoriteTrains =>
      _favorites.whereType<FavoriteTrain>().toList();
  List<FavoriteBusLine> get favoriteBusLines =>
      _favorites.whereType<FavoriteBusLine>().toList();

  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasFavorites => _favorites.isNotEmpty;

  Future<void> loadFavorites(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _favorites = await _repository.getFavorites(userId);
      print('Loaded ${_favorites.length} favorites');
    } catch (e) {
      _error = 'Errore nel caricamento dei preferiti: $e';
      print('Error loading favorites: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addFavorite(FavoriteItem favorite) async {
    try {
      final success = await _repository.addFavorite(favorite);
      if (success) {
        _favorites.insert(0, favorite); // Aggiungi all'inizio della lista
        notifyListeners();
        print('Favorite added: ${favorite.id}');
      }
      return success;
    } catch (e) {
      _error = 'Errore nell\'aggiunta del preferito: $e';
      print('Error adding favorite: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(String favoriteId, String userId) async {
    try {
      final success = await _repository.removeFavorite(favoriteId, userId);
      if (success) {
        _favorites.removeWhere((fav) => fav.id == favoriteId);
        notifyListeners();
        print('Favorite removed: $favoriteId');
      }
      return success;
    } catch (e) {
      _error = 'Errore nella rimozione del preferito: $e';
      print('Error removing favorite: $e');
      return false;
    }
  }

  Future<bool> toggleFavorite(FavoriteItem favorite) async {
    final isFav = await isFavorite(favorite.id, favorite.userId);
    if (isFav) {
      return await removeFavorite(favorite.id, favorite.userId);
    } else {
      return await addFavorite(favorite);
    }
  }

  Future<bool> isFavorite(String favoriteId, String userId) async {
    return await _repository.isFavorite(favoriteId, userId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearFavorites() {
    _favorites.clear();
    notifyListeners();
  }

  // Metodi di utilità per creare oggetti FavoriteItem
  FavoriteStop createFavoriteStop({
    required String userId,
    required String name,
    required String code,
    required StopType stopType,
    double? latitude,
    double? longitude,
    String? city,
    String? region,
    String? provider,
  }) {
    final id = '${userId}_${stopType.name}_${code}';
    return FavoriteStop(
      id: id,
      addedAt: DateTime.now(),
      userId: userId,
      name: name,
      code: code,
      stopType: stopType,
      latitude: latitude,
      longitude: longitude,
      city: city,
      region: region,
      provider: provider,
    );
  }

  FavoriteTrain createFavoriteTrain({
    required String userId,
    required String trainNumber,
    required String departureStation,
    required String arrivalStation,
    required String departureTime,
    required String arrivalTime,
    String? operator,
    String? category,
    String? routeId,
    String? provider,
  }) {
    final id = '${userId}_train_${trainNumber}_${departureStation}_${arrivalStation}';
    return FavoriteTrain(
      id: id,
      addedAt: DateTime.now(),
      userId: userId,
      trainNumber: trainNumber,
      departureStation: departureStation,
      arrivalStation: arrivalStation,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      operator: operator,
      category: category,
      routeId: routeId,
      provider: provider,
    );
  }

  FavoriteBusLine createFavoriteBusLine({
    required String userId,
    required String lineCode,
    required String lineName,
    required String provider,
    String? routeId,
    String? agencyId,
    String? color,
    String? textColor,
    String? description,
    String? url,
    List<String>? stops,
  }) {
    final id = '${userId}_bus_${provider}_${lineCode}';
    return FavoriteBusLine(
      id: id,
      addedAt: DateTime.now(),
      userId: userId,
      lineCode: lineCode,
      lineName: lineName,
      provider: provider,
      routeId: routeId,
      agencyId: agencyId,
      color: color,
      textColor: textColor,
      description: description,
      url: url,
      stops: stops,
    );
  }

  // Metodi specifici per le linee di bus
  bool isBusLineFavorite(String lineCode, String provider) {
    return _favorites.any((fav) =>
        fav is FavoriteBusLine &&
        fav.lineCode == lineCode &&
        fav.provider == provider);
  }

  Future<bool> addBusLineFavorite(FavoriteBusLine favoriteBusLine) async {
    return await addFavorite(favoriteBusLine);
  }

  Future<bool> removeBusLineFavorite(String lineCode, String provider) async {
    final favorite = _favorites.firstWhere(
      (fav) =>
          fav is FavoriteBusLine &&
          fav.lineCode == lineCode &&
          fav.provider == provider,
      orElse: () => throw Exception('Favorite bus line not found'),
    );
    return await removeFavorite(favorite.id, favorite.userId);
  }

  // Metodi specifici per i treni
  bool isTrainFavorite(String trainNumber, String departureStation, String arrivalStation) {
    return _favorites.any((fav) =>
        fav is FavoriteTrain &&
        fav.trainNumber == trainNumber &&
        fav.departureStation == departureStation &&
        fav.arrivalStation == arrivalStation);
  }

  Future<bool> addTrainFavorite(FavoriteTrain favoriteTrain) async {
    return await addFavorite(favoriteTrain);
  }

  Future<bool> removeTrainFavorite(String trainNumber, String departureStation, String arrivalStation) async {
    final favorite = _favorites.firstWhere(
      (fav) =>
          fav is FavoriteTrain &&
          fav.trainNumber == trainNumber &&
          fav.departureStation == departureStation &&
          fav.arrivalStation == arrivalStation,
      orElse: () => throw Exception('Favorite train not found'),
    );
    return await removeFavorite(favorite.id, favorite.userId);
  }

  // Metodi specifici per le fermate
  bool isStopFavorite(String code, StopType stopType) {
    return _favorites.any((fav) =>
        fav is FavoriteStop &&
        fav.code == code &&
        fav.stopType == stopType);
  }

  Future<bool> addStopFavorite(FavoriteStop favoriteStop) async {
    return await addFavorite(favoriteStop);
  }

  Future<bool> removeStopFavorite(String code, StopType stopType) async {
    final favorite = _favorites.firstWhere(
      (fav) =>
          fav is FavoriteStop &&
          fav.code == code &&
          fav.stopType == stopType,
      orElse: () => throw Exception('Favorite stop not found'),
    );
    return await removeFavorite(favorite.id, favorite.userId);
  }
}