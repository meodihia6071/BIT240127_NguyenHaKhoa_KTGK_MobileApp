import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';

/// Change this to the base URL of YOUR MockAPI project.
const mockApiBaseUrl = 'https://6ad71435f71f154ac487b5f0.mockapi.io';
const categoriesResource = 'BIT240127_DishCategory';
const dishesResource = 'BIT240127_Dish';

class Store extends ChangeNotifier {
  final List<DishCategory> categories = [];
  final List<Dish> dishes = [];
  late SharedPreferences prefs;
  StreamSubscription<List<ConnectivityResult>>? _network;
  Timer? _retry;
  bool syncing = false;
  bool isVietnamese = false;
  String? syncError;

  String tr(String en, String vi) => isVietnamese ? vi : en;
  bool get pending => categories.any((e) => e.dirty) || dishes.any((e) => e.dirty);
  List<DishCategory> get activeCategories => categories.where((e) => !e.deleted).toList();
  List<Dish> get activeDishes => dishes.where((e) => !e.deleted).toList();
  String categoryName(String uid) => categories.where((c) => c.uid == uid).map((e) => e.name).firstOrNull ?? '-';

  Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();
    isVietnamese = prefs.getBool('BIT240127_language_vi') ?? false;
    for (final j in jsonDecode(prefs.getString('BIT240127_categories') ?? '[]') as List) {
      categories.add(DishCategory.fromLocal(Map<String, dynamic>.from(j)));
    }
    for (final j in jsonDecode(prefs.getString('BIT240127_dishes') ?? '[]') as List) {
      dishes.add(Dish.fromLocal(Map<String, dynamic>.from(j)));
    }
    notifyListeners();
    _network = Connectivity().onConnectivityChanged.listen((_) => sync());
    _retry = Timer.periodic(const Duration(seconds: 15), (_) => sync());
    unawaited(sync());
  }
  void switchLanguage() {
    isVietnamese = !isVietnamese;
    prefs.setBool('BIT240127_language_vi', isVietnamese);
    notifyListeners();
  }
  Future<void> persist() async {
    await prefs.setString('BIT240127_categories',
      encodeList(categories.map((e) => e.toLocal()).toList()));
    await prefs.setString('BIT240127_dishes',
      encodeList(dishes.map((e) => e.toLocal()).toList()));
    notifyListeners();
  }
  String? validateDish(Dish d, {String? excludingUid}) {
    if (d.name.trim().isEmpty) return tr('Name is required', 'Tên không được để trống');
    if (d.price <= 0) return tr('Price must be greater than 0', 'Giá phải lớn hơn 0');
    if (d.preparationTime <= 0) return tr('Preparation time must be positive', 'Thời gian phải lớn hơn 0');
    if (!activeCategories.any((e) => e.uid == d.categoryUid)) return tr('Choose a valid category', 'Chọn loại món hợp lệ');
    if (activeDishes.any((e) => e.uid != excludingUid &&
      e.categoryUid == d.categoryUid && e.name.toLowerCase().trim() == d.name.toLowerCase().trim())) {
      return tr('Dish name already exists in this category', 'Tên món đã có trong loại này');
    }
    if (d.images.where((e) => e.isThumbnail).length > 1) return tr('Only one thumbnail is allowed', 'Chỉ được chọn một ảnh đại diện');
    return null;
  }
  Future<void> saveDish(Dish d) async {
    final error = validateDish(d, excludingUid: d.uid);
    if (error != null) throw StateError(error);
    d.dirty = true;
    final index = dishes.indexWhere((e) => e.uid == d.uid);
    if (index < 0) { dishes.add(d); } else { dishes[index] = d; }
    await persist();
    unawaited(sync());
  }
  Future<void> deleteDish(Dish d) async {
    d.deleted = true; d.dirty = true;
    await persist(); unawaited(sync());
  }
  Future<void> saveCategory(DishCategory c) async {
    if (c.name.trim().isEmpty) throw StateError(tr('Category name required', 'Tên loại món không được trống'));
    if (activeCategories.any((e) => e.uid != c.uid && e.name.toLowerCase().trim() == c.name.toLowerCase().trim())) {
      throw StateError(tr('Category already exists', 'Loại món đã tồn tại'));
    }
    c.dirty = true;
    final index = categories.indexWhere((e) => e.uid == c.uid);
    if (index < 0) { categories.add(c); } else { categories[index] = c; }
    await persist(); unawaited(sync());
  }
  Future<void> deleteCategory(DishCategory c) async {
    if (activeDishes.any((e) => e.categoryUid == c.uid)) throw StateError(
      tr('Category contains dishes', 'Không thể xóa loại còn món ăn'));
    c.deleted = true; c.dirty = true;
    await persist(); unawaited(sync());
  }

  Uri endpoint(String resource, [String? id]) => Uri.parse(
    '$mockApiBaseUrl/$resource${id == null ? '' : '/${Uri.encodeComponent(id)}'}');
  Future<dynamic> request(String method, Uri url, [Map<String, dynamic>? payload]) async {
    final headers = {'Content-Type': 'application/json'};
    final http.Response r = switch (method) {
      'GET' => await http.get(url).timeout(const Duration(seconds: 8)),
      'POST' => await http.post(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 8)),
      'PUT' => await http.put(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 8)),
      'DELETE' => await http.delete(url).timeout(const Duration(seconds: 8)),
      _ => throw StateError('Unsupported HTTP method'),
    };
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }
  Future<List<Map<String, dynamic>>> fetch(String resource) async =>
    (await request('GET', endpoint(resource)) as List)
      .map((e) => Map<String, dynamic>.from(e as Map)).toList();

  /// Local values are authoritative while dirty. ClientUid makes POST retry idempotent
  /// *when the previous POST succeeded but its response was lost*.
  Future<void> sync() async {
    if (syncing || mockApiBaseUrl.contains('YOUR_PROJECT_ID')) return;
    syncing = true; notifyListeners();
    try {
      final remoteCats = await fetch(categoriesResource);
      final remoteDishes = await fetch(dishesResource);
      for (final c in List<DishCategory>.from(categories.where((e) => e.dirty))) {
        var matching = remoteCats.where((e) => e[Keys.k('ClientUid')] == c.uid).firstOrNull;
        c.remoteId ??= matching?['id']?.toString();
        if (c.deleted) {
          if (c.remoteId != null) await request('DELETE', endpoint(categoriesResource, c.remoteId));
          categories.remove(c);
        } else if (c.remoteId == null) {
          final data = await request('POST', endpoint(categoriesResource), c.toJson()) as Map;
          c.remoteId = data['id'].toString(); c.dirty = false;
        } else {
          await request('PUT', endpoint(categoriesResource, c.remoteId), c.toJson());
          c.dirty = false;
        }
        await persist();
      }
      for (final d in List<Dish>.from(dishes.where((e) => e.dirty))) {
        final matching = remoteDishes.where((e) => e[Keys.k('ClientUid')] == d.uid).firstOrNull;
        d.remoteId ??= matching?['id']?.toString();
        if (d.deleted) {
          if (d.remoteId != null) await request('DELETE', endpoint(dishesResource, d.remoteId));
          dishes.remove(d);
        } else if (d.remoteId == null) {
          final data = await request('POST', endpoint(dishesResource), d.toJson()) as Map;
          d.remoteId = data['id'].toString(); d.dirty = false;
        } else {
          await request('PUT', endpoint(dishesResource, d.remoteId), d.toJson());
          d.dirty = false;
        }
        await persist();
      }
      // Re-fetch after writes so the local list includes other devices' changes.
      final refreshedCats = (await fetch(categoriesResource)).map(DishCategory.fromJson).toList();
      final refreshedDishes = (await fetch(dishesResource)).map(Dish.fromJson).toList();
      _merge(categories, refreshedCats, (DishCategory c) => c.uid,
        (DishCategory c) => c.dirty);
      _merge(dishes, refreshedDishes, (Dish d) => d.uid, (Dish d) => d.dirty);
      syncError = null;
      await persist();
    } catch (e) {
      syncError = e.toString();
      notifyListeners();
    } finally {
      syncing = false; notifyListeners();
    }
  }
  void _merge<T>(List<T> local, List<T> remote, String Function(T) uid,
      bool Function(T) dirty) {
    final pendingItems = local.where(dirty).toList();
    local..clear()..addAll(remote.where((r) => !pendingItems.any((l) => uid(l) == uid(r))))
      ..addAll(pendingItems);
  }
  @override
  void dispose() { _network?.cancel(); _retry?.cancel(); super.dispose(); }
}
