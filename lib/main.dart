import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(const AutoTerminyApp());
}

class TermItem {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;

  TermItem({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
      };

  factory TermItem.fromMap(Map<String, dynamic> map) => TermItem(
        id: map['id'],
        title: map['title'],
        description: map['description'],
        dueDate: DateTime.parse(map['dueDate']),
      );
}

class CategoryConfig {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryConfig({
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<CategoryConfig> appCategories = [
  CategoryConfig(
    name: 'Badanie techniczne',
    icon: Icons.fact_check_rounded,
    color: Color(0xFF2563EB),
  ),
  CategoryConfig(
    name: 'Polisa OC/AC',
    icon: Icons.shield_rounded,
    color: Color(0xFF059669),
  ),
  CategoryConfig(
    name: 'Wymiana oleju/filtrów',
    icon: Icons.build_rounded,
    color: Color(0xFFD97706),
  ),
  CategoryConfig(
    name: 'Wymiana opon',
    icon: Icons.tire_repair_rounded,
    color: Color(0xFF7C3AED),
  ),
  CategoryConfig(
    name: 'Serwis klimatyzacji',
    icon: Icons.ac_unit_rounded,
    color: Color(0xFF0284C7),
  ),
  CategoryConfig(
    name: 'Gaśnica / Inne',
    icon: Icons.fire_extinguisher_rounded,
    color: Color(0xFFDC2626),
  ),
];

CategoryConfig getCategoryConfig(String title) {
  return appCategories.firstWhere(
    (c) => c.name == title,
    orElse: () => appCategories.last,
  );
}

class AutoTerminyApp extends StatelessWidget {
  const AutoTerminyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Terminy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TermItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  int _calculateDaysLeft(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('saved_terms');
    if (itemsJson != null) {
      final List<dynamic> decoded = jsonDecode(itemsJson);
      setState(() {
        _items = decoded.map((e) => TermItem.fromMap(e)).toList();
        _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((e) => e.toMap()).toList());
    await prefs.setString('saved_terms', encoded);
  }

  Future<void> _scheduleNotifications(TermItem item) async {
    final int baseId = item.id.hashCode;

    // Powiadomienie 7 dni przed o 09:00
    DateTime reminder7Days = item.dueDate.subtract(const Duration(days: 7));
    reminder7Days = DateTime(
        reminder7Days.year, reminder7Days.month, reminder7Days.day, 9, 0);

    if (reminder7Days.isAfter(DateTime.now())) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        baseId,
        'Za tydzień mija termin: ${item.title}',
        'Data: ${DateFormat('dd.MM
