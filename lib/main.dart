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

class AutoTerminyApp extends StatelessWidget {
  const AutoTerminyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Terminy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
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

  Future<void> _scheduleNotification(TermItem item) async {
    DateTime reminderDate = item.dueDate.subtract(const Duration(days: 7));
    reminderDate = DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 9, 0);

    if (reminderDate.isBefore(DateTime.now())) {
      reminderDate = DateTime.now().add(const Duration(seconds: 15)); 
    }

    final int notificationId = item.id.hashCode;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Zbliża się termin: ${item.title}',
      'Upływa: ${DateFormat('dd.MM.yyyy').format(item.dueDate)} (${item.description})',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'auto_terminy_channel',
          'Przypomnienia',
          channelDescription: 'Powiadomienia o przeglądach i polisach',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _deleteItem(int index) async {
    final item = _items[index];
    await flutterLocalNotificationsPlugin.cancel(item.id.hashCode);
    setState(() {
      _items.removeAt(index);
    });
    await _saveItems();
  }

  void _showAddDialog() {
    final descController = TextEditingController();
    DateTime? selectedDate;
    String selectedCategory = 'Badanie techniczne';

    final categories = ['Badanie techniczne', 'Polisa OC/AC', 'Wymiana oleju/filtrów', 'Inne'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Dodaj nowe przypomnienie',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: categories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  setModalState(() {
                    selectedCategory = val!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Kategoria'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Opis (np. Nissan Qashqai, PZU)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? 'Nie wybrano daty'
                          : 'Termin: ${DateFormat('dd.MM.yyyy').format(selectedDate!)}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: const Text('Wybierz datę'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (selectedDate == null) return;
                  final newItem = TermItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: selectedCategory,
                    description: descController.text.trim(),
                    dueDate: selectedDate!,
                  );
                  setState(() {
                    _items.add(newItem);
                    _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                  });
                  await _saveItems();
                  await _scheduleNotification(newItem);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Zapisz termin'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Terminy'),
        centerTitle: true,
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text('Brak wpisów. Kliknij +, aby dodać pierwszy termin.'),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                final daysLeft = item.dueDate.difference(DateTime.now()).inDays;
                final isUrgent = daysLeft <= 14;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isUrgent ? Colors.redAccent : Colors.blueAccent,
                      child: Icon(
                        isUrgent ? Icons.warning_amber_rounded : Icons.event_available,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${item.description.isNotEmpty ? '${item.description}\n' : ''}'
                      'Termin: ${DateFormat('dd.MM.yyyy').format(item.dueDate)} (zostało: $daysLeft dni)',
                    ),
                    isThreeLine: item.description.isNotEmpty,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteItem(i),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
