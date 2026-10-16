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

class CategoryStyle {
  final IconData icon;
  final Color color;
  CategoryStyle(this.icon, this.color);
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
          seedColor: const Color(0xFF1E3C72),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
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

  final Map<String, CategoryStyle> _categories = {
    'Badanie techniczne': CategoryStyle(Icons.fact_check_rounded, const Color(0xFF1976D2)),
    'Polisa OC/AC': CategoryStyle(Icons.shield_rounded, const Color(0xFF512DA8)),
    'Wymiana oleju/filtrów': CategoryStyle(Icons.build_circle_rounded, const Color(0xFFE65100)),
    'Wymiana opon': CategoryStyle(Icons.album_rounded, const Color(0xFF00796B)),
    'Klimatyzacja / Serwis': CategoryStyle(Icons.ac_unit_rounded, const Color(0xFF0288D1)),
    'Gaśnica / Wyposażenie': CategoryStyle(Icons.local_fire_department_rounded, const Color(0xFFD32F2F)),
    'Inne': CategoryStyle(Icons.directions_car_filled_rounded, const Color(0xFF455A64)),
  };

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
      'Upływa: ${DateFormat('dd.MM.yyyy').format(item.dueDate)} ${item.description.isNotEmpty ? "(${item.description})" : ""}',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'auto_terminy_channel',
          'Przypomnienia o terminach',
          channelDescription: 'Powiadomienia o przeglądach, OC i serwisie',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _extendOneYear(int index) async {
    final oldItem = _items[index];
    final newDate = DateTime(
      oldItem.dueDate.year + 1,
      oldItem.dueDate.month,
      oldItem.dueDate.day,
    );
    final updatedItem = TermItem(
      id: oldItem.id,
      title: oldItem.title,
      description: oldItem.description,
      dueDate: newDate,
    );

    setState(() {
      _items[index] = updatedItem;
      _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });
    await _saveItems();
    await _scheduleNotification(updatedItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Przedłużono "${oldItem.title}" do ${DateFormat('dd.MM.yyyy').format(newDate)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    String selectedCategory = _categories.keys.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3C72).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_alarm_rounded, color: Color(0xFF1E3C72)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Nowe przypomnienie',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FC),
                ),
                items: _categories.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon, color: entry.value.color, size: 22),
                        const SizedBox(width: 10),
                        Text(entry.key),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setModalState(() {
                    selectedCategory = val!;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Opis / Pojazd (np. Nissan Qashqai, PZU)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FC),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setModalState(() {
                      selectedDate = picked;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF1E3C72)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'Kliknij, aby wybrać datę ważności'
                              : 'Data ważności: ${DateFormat('dd.MM.yyyy').format(selectedDate!)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.bold,
                            color: selectedDate == null ? Colors.grey.shade700 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                child: const Text('Zapisz przypomnienie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int urgentCount, int okCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mój Garaż',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Asystent badań, polis i serwisu',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$okCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const Text('W normie', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: urgentCount > 0 ? Colors.redAccent.withOpacity(0.25) : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: urgentCount > 0 ? Border.all(color: Colors.redAccent.shade100, width: 1) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: urgentCount > 0 ? Colors.amberAccent : Colors.white54, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$urgentCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const Text('Pilne (≤14 dni)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urgentCount = _items.where((e) => _calculateDaysLeft(e.dueDate) <= 14).length;
    final okCount = _items.length - urgentCount;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(urgentCount, okCount),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.car_repair_rounded, size: 88, color: Colors.blueGrey.shade200),
                          const SizedBox(height: 16),
                          const Text(
                            'Brak zapisanych terminów',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kliknij przycisk "Dodaj termin" na dole ekranu, aby ustawić przypomnienie o przeglądzie, OC lub wymianie oleju.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      final daysLeft = _calculateDaysLeft(item.dueDate);
                      final style = _categories[item.title] ?? _categories['Inne']!;

                      Color statusColor = Colors.green.shade600;
                      String statusText = 'Za $daysLeft dni';
                      if (daysLeft < 0) {
                        statusColor = Colors.red.shade800;
                        statusText = 'Po terminie (${daysLeft.abs()} dni)';
                      } else if (daysLeft == 0) {
                        statusColor = Colors.red.shade700;
                        statusText = 'Dzisiaj!';
                      } else if (daysLeft <= 14) {
                        statusColor = Colors.redAccent.shade700;
                      } else if (daysLeft <= 30) {
                        statusColor = Colors.orange.shade800;
                      }

                      final double progress = (daysLeft / 365.0).clamp(0.05, 1.0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: style.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(style.icon, color: style.color, size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        if (item.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.description,
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.event, size: 15, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('dd.MM.yyyy').format(item.dueDate),
                                              style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _extendOneYear(i),
                                    icon: const Icon(Icons.update_rounded, size: 18),
                                    label: const Text('+1 rok'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E3C72),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _deleteItem(i),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    label: const Text('Usuń'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade600,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dodaj termin', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
