import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/store.dart';

void message(BuildContext context, String text) => ScaffoldMessenger.of(context)
  .showSnackBar(SnackBar(content: Text(text)));
Future<bool> confirm(BuildContext context, String question) async => await showDialog<bool>(
  context: context, builder: (c) => AlertDialog(title: Text(question), actions: [
    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel / Hủy')),
    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
  ])) ?? false;

class FoodPhoto extends StatelessWidget {
  final String? url;
  final double? width;
  final double height;
  const FoodPhoto({super.key, this.url, this.width, this.height = 92});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height,
    child: url == null || url!.isEmpty
      ? const ColoredBox(color: Color(0xFFFFEDD5), child: Icon(Icons.restaurant, size: 38))
      : Image.network(url!, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFFFFEDD5),
          child: Icon(Icons.broken_image_outlined))));
}

class HomeScreen extends StatefulWidget {
  final Store store;
  const HomeScreen({super.key, required this.store});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  String search = '';
  String category = '';
  bool availableOnly = false;
  String minPrice = '';
  String maxPrice = '';
  String sort = 'name';
  final searchCtrl = TextEditingController();
  final minCtrl = TextEditingController();
  final maxCtrl = TextEditingController();
  @override void dispose() { searchCtrl.dispose(); minCtrl.dispose(); maxCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final s = widget.store;
    return AnimatedBuilder(animation: s, builder: (context, _) {
      final min = double.tryParse(minPrice.trim());
      final max = double.tryParse(maxPrice.trim());
      final invalidRange = (minPrice.isNotEmpty && min == null) || (maxPrice.isNotEmpty && max == null) ||
        (min != null && max != null && min > max) || (min != null && min < 0) || (max != null && max < 0);
      final filtered = s.activeDishes.where((d) =>
        d.name.toLowerCase().contains(search.trim().toLowerCase()) &&
        (category.isEmpty || d.categoryUid == category) &&
        (!availableOnly || d.isAvailable) &&
        (min == null || d.price >= min) && (max == null || d.price <= max)).toList();
      filtered.sort((a, b) => switch (sort) {
        'priceUp' => a.price.compareTo(b.price),
        'priceDown' => b.price.compareTo(a.price),
        'time' => a.preparationTime.compareTo(b.preparationTime),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      });
      return Scaffold(
        appBar: AppBar(title: const Text('BIT240127_FoodManager'), actions: [
          IconButton(tooltip: 'English / Tiếng Việt', onPressed: s.switchLanguage,
            icon: const Icon(Icons.language)),
          IconButton(tooltip: s.tr('Sync', 'Đồng bộ'), onPressed: s.sync,
            icon: const Icon(Icons.sync)),
          IconButton(tooltip: s.tr('Categories', 'Loại món'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CategoryScreen(store: s))), icon: const Icon(Icons.category_outlined)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DishForm(store: s))),
          icon: const Icon(Icons.add), label: Text(s.tr('Add dish', 'Thêm món'))),
        body: Column(children: [
          if (s.syncing || s.pending || s.syncError != null)
            MaterialBanner(content: Text(s.syncing ? s.tr('Syncing...', 'Đang đồng bộ...') :
              s.pending ? s.tr('Saved locally; waiting for sync', 'Đã lưu offline; chờ đồng bộ') :
              s.tr('Unable to reach MockAPI', 'Chưa kết nối được MockAPI')),
              actions: [TextButton(onPressed: s.sync, child: const Text('Retry'))]),
          Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            TextField(controller: searchCtrl, onChanged: (v) => setState(() => search = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
                labelText: s.tr('Search dishes', 'Tìm món ăn'), border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                key: ValueKey(category), value: s.activeCategories.any((c) => c.uid == category) ? category : '',
                isExpanded: true, decoration: InputDecoration(labelText: s.tr('Category', 'Loại món'),
                  border: const OutlineInputBorder()), items: [
                  DropdownMenuItem(value: '', child: Text(s.tr('All', 'Tất cả'))),
                  ...s.activeCategories.map((c) => DropdownMenuItem(value: c.uid, child: Text(c.name))),
                ], onChanged: (v) => setState(() => category = v ?? ''))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: sort, isExpanded: true,
                decoration: InputDecoration(labelText: s.tr('Sort', 'Sắp xếp'),
                  border: const OutlineInputBorder()), items: [
                    DropdownMenuItem(value: 'name', child: Text(s.tr('Name', 'Tên'))),
                    DropdownMenuItem(value: 'priceUp', child: Text(s.tr('Price ↑', 'Giá ↑'))),
                    DropdownMenuItem(value: 'priceDown', child: Text(s.tr('Price ↓', 'Giá ↓'))),
                    DropdownMenuItem(value: 'time', child: Text(s.tr('Prep time ↑', 'Thời gian ↑'))),
                  ], onChanged: (v) => setState(() => sort = v ?? 'name'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.tr('Min price', 'Giá từ'), border: const OutlineInputBorder()),
                onChanged: (v) => setState(() => minPrice = v))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: maxCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.tr('Max price', 'Giá đến'), border: const OutlineInputBorder()),
                onChanged: (v) => setState(() => maxPrice = v))),
            ]),
            if (invalidRange) Text(s.tr('Invalid price range', 'Khoảng giá không hợp lệ'),
              style: const TextStyle(color: Colors.red)),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: availableOnly,
              title: Text(s.tr('Available only', 'Chỉ món đang bán')),
              onChanged: (v) => setState(() => availableOnly = v)),
          ])),
          Expanded(child: invalidRange ? const SizedBox.shrink() : filtered.isEmpty
            ? Center(child: Text(s.tr('No dishes found', 'Không tìm thấy món ăn')))
            : RefreshIndicator(onRefresh: s.sync, child: ListView.builder(
              itemCount: filtered.length, itemBuilder: (context, i) {
                final d = filtered[i];
                return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(leading: FoodPhoto(url: d.thumbnail, width: 76),
                    title: Text(d.name),
                    subtitle: Text('${s.categoryName(d.categoryUid)} · ${d.price.toStringAsFixed(0)} VND\n'
                      '${d.preparationTime} min · ${d.preparationTime <= 15 ? s.tr('Quick', 'Nhanh') : s.tr('Regular', 'Thông thường')} · '
                      '${d.isAvailable ? s.tr('Available', 'Đang bán') : s.tr('Unavailable', 'Ngừng bán')}'),
                    isThreeLine: true, trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DishDetail(store: s, uid: d.uid)))));
              }))),
        ]),
      );
    });
  }
}

class DishDetail extends StatelessWidget {
  final Store store;
  final String uid;
  const DishDetail({super.key, required this.store, required this.uid});
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: store,
    builder: (context, _) {
      final matches = store.activeDishes.where((e) => e.uid == uid);
      if (matches.isEmpty) return Scaffold(appBar: AppBar(),
        body: Center(child: Text(store.tr('Dish not found', 'Không tìm thấy món'))));
      final d = matches.first;
      return Scaffold(appBar: AppBar(title: Text(store.tr('Dish details', 'Chi tiết món')),
        actions: [IconButton(icon: const Icon(Icons.edit), tooltip: store.tr('Edit', 'Sửa'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => DishForm(store: store, existingUid: uid))),),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: store.tr('Delete', 'Xóa'),
            onPressed: () async {
              if (!await confirm(context, store.tr('Delete this dish?', 'Xóa món này?'))) return;
              await store.deleteDish(d);
              if (context.mounted) Navigator.pop(context);
            })]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(d.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('${store.categoryName(d.categoryUid)} · ${d.price.toStringAsFixed(0)} VND'),
          Text('${d.preparationTime} min — ${d.preparationTime <= 15 ? store.tr('Quick', 'Nhanh') : store.tr('Regular', 'Thông thường')}'),
          Text(d.isAvailable ? store.tr('Available', 'Đang bán') : store.tr('Unavailable', 'Ngừng bán')),
          const SizedBox(height: 12), Text(d.description), const SizedBox(height: 12),
          Text(store.tr('Photos', 'Hình ảnh'), style: Theme.of(context).textTheme.titleLarge),
          if (d.images.isEmpty) Text(store.tr('No photos', 'Chưa có ảnh')),
          ...d.images.map((im) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FoodPhoto(url: im.imageUrl, height: 210),
              if (im.isThumbnail) Text(store.tr('Thumbnail', 'Ảnh đại diện')),
            ]))),
        ]));
    });
}

class DishForm extends StatefulWidget {
  final Store store;
  final String? existingUid;
  const DishForm({super.key, required this.store, this.existingUid});
  @override State<DishForm> createState() => _DishFormState();
}
class _DishFormState extends State<DishForm> {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final timeCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final imageCtrl = TextEditingController();
  final images = <String>[];
  int thumbnail = 0;
  String? categoryUid;
  bool available = true;
  late String uid;
  String? remoteId;
  @override void initState() {
    super.initState();
    final old = widget.store.dishes.where((e) => e.uid == widget.existingUid).firstOrNull;
    uid = old?.uid ?? newUid(); remoteId = old?.remoteId;
    nameCtrl.text = old?.name ?? '';
    priceCtrl.text = old?.price.toStringAsFixed(0) ?? '';
    timeCtrl.text = old?.preparationTime.toString() ?? '';
    descriptionCtrl.text = old?.description ?? '';
    categoryUid = old?.categoryUid;
    available = old?.isAvailable ?? true;
    if (old != null) {
      images.addAll(old.images.map((e) => e.imageUrl));
      final i = old.images.indexWhere((e) => e.isThumbnail);
      thumbnail = i < 0 ? 0 : i;
    }
  }
  @override void dispose() {
    for (final c in [nameCtrl, priceCtrl, timeCtrl, descriptionCtrl, imageCtrl]) { c.dispose(); }
    super.dispose();
  }
  bool validUrl(String v) => (Uri.tryParse(v)?.hasAbsolutePath ?? false) &&
    (v.startsWith('https://') || v.startsWith('http://'));
  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final s = widget.store;
    final d = Dish(uid: uid, remoteId: remoteId, name: nameCtrl.text.trim(),
      price: double.parse(priceCtrl.text.trim()), preparationTime: int.parse(timeCtrl.text.trim()),
      isAvailable: available, description: descriptionCtrl.text.trim(), categoryUid: categoryUid!,
      images: [for (var i = 0; i < images.length; i++)
        DishImage(imageUrl: images[i], isThumbnail: i == thumbnail)]);
    try {
      await s.saveDish(d);
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) message(context, e.toString()); }
  }
  @override Widget build(BuildContext context) {
    final s = widget.store;
    return AnimatedBuilder(animation: s, builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(widget.existingUid == null ?
        s.tr('Add dish', 'Thêm món') : s.tr('Edit dish', 'Sửa món'))),
      body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
        TextFormField(controller: nameCtrl, decoration: InputDecoration(labelText: s.tr('Dish name', 'Tên món')),
          validator: (v) => v == null || v.trim().isEmpty ? s.tr('Name is required', 'Không được để trống') :
            s.activeDishes.any((e) => e.uid != uid && e.categoryUid == categoryUid &&
              e.name.toLowerCase().trim() == v.toLowerCase().trim()) ?
              s.tr('Duplicate name in this category', 'Trùng tên trong loại món') : null),
        TextFormField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s.tr('Price (VND)', 'Giá (VND)')),
          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? s.tr('Enter price > 0', 'Nhập giá > 0') : null),
        TextFormField(controller: timeCtrl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: s.tr('Preparation time (minutes)', 'Thời gian chế biến (phút)')),
          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? s.tr('Enter time > 0', 'Nhập thời gian > 0') : null),
        DropdownButtonFormField<String>(value: s.activeCategories.any((e) => e.uid == categoryUid) ? categoryUid : null,
          decoration: InputDecoration(labelText: s.tr('Category', 'Loại món')),
          items: s.activeCategories.map((e) => DropdownMenuItem(value: e.uid, child: Text(e.name))).toList(),
          validator: (v) => v == null ? s.tr('Select a category', 'Hãy chọn loại món') : null,
          onChanged: (v) => setState(() => categoryUid = v)),
        TextFormField(controller: descriptionCtrl, maxLines: 3,
          decoration: InputDecoration(labelText: s.tr('Description', 'Mô tả'))),
        SwitchListTile(title: Text(s.tr('Available', 'Đang bán')), value: available,
          onChanged: (v) => setState(() => available = v)),
        const Divider(), Text(s.tr('Photos (URL)', 'Ảnh (URL)'), style: Theme.of(context).textTheme.titleMedium),
        Row(children: [Expanded(child: TextField(controller: imageCtrl,
            decoration: InputDecoration(labelText: s.tr('Image URL', 'Liên kết ảnh')))),
          IconButton(icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: () {
            final url = imageCtrl.text.trim();
            if (!validUrl(url)) { message(context, s.tr('Invalid HTTP image URL', 'URL ảnh không hợp lệ')); return; }
            setState(() { images.add(url); imageCtrl.clear(); });
          })]),
        ...List.generate(images.length, (i) => ListTile(
          leading: FoodPhoto(url: images[i], width: 64, height: 55),
          title: Text(images[i], maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(i == thumbnail ? s.tr('Thumbnail', 'Ảnh đại diện') : ''),
          onTap: () => setState(() => thumbnail = i),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() {
            images.removeAt(i);
            if (thumbnail >= images.length) thumbnail = images.isEmpty ? 0 : images.length - 1;
            else if (i < thumbnail) thumbnail--;
          })))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: Text(s.tr('Save', 'Lưu'))),
      ]))));
  }
}

class CategoryScreen extends StatelessWidget {
  final Store store;
  const CategoryScreen({super.key, required this.store});
  Future<void> edit(BuildContext context, [DishCategory? c]) async {
    final name = TextEditingController(text: c?.name ?? '');
    final description = TextEditingController(text: c?.description ?? '');
    final key = GlobalKey<FormState>();
    final save = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(c == null ? store.tr('Add category', 'Thêm loại') : store.tr('Edit category', 'Sửa loại')),
      content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: InputDecoration(labelText: store.tr('Name', 'Tên')),
          validator: (v) => v == null || v.trim().isEmpty ? store.tr('Required', 'Bắt buộc') : null),
        TextFormField(controller: description,
          decoration: InputDecoration(labelText: store.tr('Description', 'Mô tả'))),
      ])), actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.tr('Cancel', 'Hủy'))),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(dialogContext, true); },
          child: Text(store.tr('Save', 'Lưu'))),
      ]));
    if (save == true) {
      try {
        await store.saveCategory(DishCategory(uid: c?.uid ?? newUid(), remoteId: c?.remoteId,
          name: name.text.trim(), description: description.text.trim()));
      } catch (e) { if (context.mounted) message(context, e.toString()); }
    }
    name.dispose(); description.dispose();
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(store.tr('Categories', 'Quản lý loại món'))),
      floatingActionButton: FloatingActionButton(onPressed: () => edit(context), child: const Icon(Icons.add)),
      body: store.activeCategories.isEmpty ? Center(child: Text(store.tr('No categories', 'Chưa có loại món'))) :
        ListView(children: store.activeCategories.map((c) => ListTile(
          title: Text(c.name), subtitle: Text(c.description),
          trailing: Wrap(children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => edit(context, c)),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
              if (!await confirm(context, store.tr('Delete category?', 'Xóa loại món?'))) return;
              try { await store.deleteCategory(c); }
              catch (e) { if (context.mounted) message(context, e.toString()); }
            }),
          ]))).toList())));
}
