import 'package:flutter/material.dart';
import 'services/store.dart';
import 'screens/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.initialize();
  runApp(FoodManagerApp(store: store));
}

class FoodManagerApp extends StatelessWidget {
  final Store store;
  const FoodManagerApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BIT240127_FoodManager',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange),
      home: HomeScreen(store: store),
    ),
  );
}
