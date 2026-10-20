import 'dart:convert';

/// All keys sent to MockAPI start with the student's ID.
class Keys {
  static const prefix = 'BIT240127_';
  static String k(String field) => '$prefix$field';
}

String newUid() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
int _counter = 0;

class DishImage {
  final String imageUrl;
  final bool isThumbnail;
  const DishImage({required this.imageUrl, required this.isThumbnail});
  factory DishImage.fromJson(Map<String, dynamic> j) => DishImage(
    imageUrl: (j[Keys.k('ImageUrl')] ?? '').toString(),
    isThumbnail: j[Keys.k('IsThumbnail')] == true || j[Keys.k('IsThumbnail')] == 'true',
  );
  Map<String, dynamic> toJson() => {
    Keys.k('ImageUrl'): imageUrl,
    Keys.k('IsThumbnail'): isThumbnail,
  };
}

class DishCategory {
  String uid;
  String? remoteId;
  String name;
  String description;
  bool dirty;
  bool deleted;
  DishCategory({required this.uid, this.remoteId, required this.name,
    this.description = '', this.dirty = true, this.deleted = false});
  factory DishCategory.fromJson(Map<String, dynamic> j) => DishCategory(
    uid: (j[Keys.k('ClientUid')] ?? j['id'] ?? newUid()).toString(),
    remoteId: j['id']?.toString(),
    name: (j[Keys.k('Name')] ?? '').toString(),
    description: (j[Keys.k('Description')] ?? '').toString(), dirty: false,
  );
  Map<String, dynamic> toJson() => {
    Keys.k('ClientUid'): uid, Keys.k('Name'): name,
    Keys.k('Description'): description,
  };
  Map<String, dynamic> toLocal() => {...toJson(), 'id': remoteId,
    '_dirty': dirty, '_deleted': deleted};
  factory DishCategory.fromLocal(Map<String, dynamic> j) =>
    DishCategory.fromJson(j)..dirty = j['_dirty'] == true..deleted = j['_deleted'] == true;
}

class Dish {
  String uid;
  String? remoteId;
  String name;
  double price;
  int preparationTime;
  bool isAvailable;
  String description;
  String categoryUid;
  List<DishImage> images;
  bool dirty;
  bool deleted;
  Dish({required this.uid, this.remoteId, required this.name, required this.price,
    required this.preparationTime, required this.isAvailable,
    this.description = '', required this.categoryUid, required this.images,
    this.dirty = true, this.deleted = false});
  static double _price(Object? v) => double.tryParse('$v') ?? 0;
  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
    uid: (j[Keys.k('ClientUid')] ?? j['id'] ?? newUid()).toString(),
    remoteId: j['id']?.toString(),
    name: (j[Keys.k('Name')] ?? '').toString(),
    price: _price(j[Keys.k('Price')]),
    preparationTime: int.tryParse('${j[Keys.k('PreparationTime')]}') ?? 0,
    isAvailable: j[Keys.k('IsAvailable')] == true || j[Keys.k('IsAvailable')] == 'true',
    description: (j[Keys.k('Description')] ?? '').toString(),
    categoryUid: (j[Keys.k('DishCategoryId')] ?? '').toString(),
    images: ((j[Keys.k('DishImage')] as List?) ?? []).whereType<Map>()
      .map((e) => DishImage.fromJson(Map<String, dynamic>.from(e))).toList(),
    dirty: false,
  );
  Map<String, dynamic> toJson() => {
    Keys.k('ClientUid'): uid, Keys.k('Name'): name,
    Keys.k('Price'): price, Keys.k('PreparationTime'): preparationTime,
    Keys.k('IsAvailable'): isAvailable, Keys.k('Description'): description,
    Keys.k('DishCategoryId'): categoryUid,
    Keys.k('DishImage'): images.map((e) => e.toJson()).toList(),
  };
  Map<String, dynamic> toLocal() => {...toJson(), 'id': remoteId,
    '_dirty': dirty, '_deleted': deleted};
  factory Dish.fromLocal(Map<String, dynamic> j) =>
    Dish.fromJson(j)..dirty = j['_dirty'] == true..deleted = j['_deleted'] == true;
  String? get thumbnail => images.isEmpty ? null :
    images.firstWhere((e) => e.isThumbnail, orElse: () => images.first).imageUrl;
}

String encodeList(List<Map<String, dynamic>> values) => jsonEncode(values);
