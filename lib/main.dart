import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('pl_PL', null);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(const PrzypominajkaApp());
}

class TermItem {
  final String id;
  final String carName;
  final String title;
  final String description;
  final DateTime dueDate;

  TermItem({
    required this.id,
    required this.carName,
    required this.title,
    required this.description,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'carName': carName,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
      };

  factory TermItem.fromMap(Map<String, dynamic> map) => TermItem(
        id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        carName: map['carName'] ?? 'Domyślne auto',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        dueDate: DateTime.parse(map['dueDate']),
      );
}

class RepairItem {
  final String id;
  final String carName;
  final String title;
  final double cost;
  final String mileage;
  final String workshop;
  final DateTime date;

  RepairItem({
    required this.id,
    required this.carName,
    required this.title,
    required this.cost,
    required this.mileage,
    required this.workshop,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'carName': carName,
        'title': title,
        'cost': cost,
        'mileage': mileage,
        'workshop': workshop,
        'date': date.toIso8601String(),
      };

  factory RepairItem.fromMap(Map<String, dynamic> map) => RepairItem(
        id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        carName: map['carName'] ?? 'Domyślne auto',
        title: map['title'] ?? 'Naprawa',
        cost: (map['cost'] ?? 0.0).toDouble(),
        mileage: map['mileage'] ?? '',
        workshop: map['workshop'] ?? '',
        date: DateTime.parse(map['date']),
      );
}

class CategoryStyle {
  final IconData icon;
  final Color color;
  CategoryStyle(this.icon, this.color);
}

class PrzypominajkaApp extends StatefulWidget {
  const PrzypominajkaApp({super.key});

  @override
  State<PrzypominajkaApp> createState() => _PrzypominajkaAppState();
}

class _PrzypominajkaAppState extends State<PrzypominajkaApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Przypominajka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3C72),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3C72),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<TermItem> _terms = [];
  List<RepairItem> _repairs = [];
  List<String> _cars = ['Nissan Qashqai'];
  String? _selectedCarFilter;

  final Map<String, CategoryStyle> _termCategories = {
    'Badanie techniczne': CategoryStyle(Icons.fact_check_rounded, const Color(0xFF1976D2)),
    'Polisa OC/AC': CategoryStyle(Icons.shield_rounded, const Color(0xFF512DA8)),
    'Wymiana oleju/filtrów': CategoryStyle(Icons.build_circle_rounded, const Color(0xFFE65100)),
    'Wymiana opon': CategoryStyle(Icons.album_rounded, const Color(0xFF00796B)),
    'Klimatyzacja / Serwis': CategoryStyle(Icons.ac_unit_rounded, const Color(0xFF0288D1)),
    'Inne': CategoryStyle(Icons.directions_car_filled_rounded, const Color(0xFF455A64)),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cars
    final List<String>? savedCars = prefs.getStringList('saved_cars');
    if (savedCars != null && savedCars.isNotEmpty) {
      _cars = savedCars;
    }

    // Terms
    final String? termsJson = prefs.getString('saved_terms');
    if (termsJson != null) {
      final List<dynamic> decoded = jsonDecode(termsJson);
      _terms = decoded.map((e) => TermItem.fromMap(e)).toList();
      _terms.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }

    // Repairs
    final String? repairsJson = prefs.getString('saved_repairs');
    if (repairsJson != null) {
      final List<dynamic> decoded = jsonDecode(repairsJson);
      _repairs = decoded.map((e) => RepairItem.fromMap(e)).toList();
      _repairs.sort((a, b) => b.date.compareTo(a.date));
    }

    setState(() {});
  }

  Future<void> _saveCars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_cars', _cars);
  }

  Future<void> _saveTerms() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_terms.map((e) => e.toMap()).toList());
    await prefs.setString('saved_terms', encoded);
  }

  Future<void> _saveRepairs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_repairs.map((e) => e.toMap()).toList());
    await prefs.setString('saved_repairs', encoded);
  }

  int _calculateDaysLeft(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
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
      'Zbliża się termin: ${item.title} (${item.carName})',
      'Upływa: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(item.dueDate)} ${item.description.isNotEmpty ? "(${item.description})" : ""}',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'przypominajka_channel',
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

  void _showManageCarsDialog() {
    final carController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zarządzaj pojazdami'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: carController,
                  decoration: const InputDecoration(
                    labelText: 'Nowe auto (np. Skoda Octavia)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    if (carController.text.trim().isNotEmpty) {
                      setState(() {
                        _cars.add(carController.text.trim());
                      });
                      _saveCars();
                      setDialogState(() {
                        carController.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj pojazd'),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text('Twoje auta:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cars.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        title: Text(_cars[index]),
                        trailing: _cars.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _cars.removeAt(index);
                                  });
                                  _saveCars();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTermDialog() {
    final descController = TextEditingController();
    DateTime? selectedDate;
    String selectedCategory = _termCategories.keys.first;
    String selectedCar = _cars.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              const Text('Nowy termin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCar,
                decoration: InputDecoration(
                  labelText: 'Pojazd',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _cars.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setModalState(() => selectedCar = val!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _termCategories.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon, color: entry.value.color, size: 20),
                        const SizedBox(width: 8),
                        Text(entry.key),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedCategory = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Dodatkowy opis (np. PZU, warsztat)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    locale: const Locale('pl', 'PL'),
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Wybierz datę ważności'
                            : 'Data: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(selectedDate!)}',
                        style: TextStyle(
                          fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.bold,
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (selectedDate == null) return;
                  final newItem = TermItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    carName: selectedCar,
                    title: selectedCategory,
                    description: descController.text.trim(),
                    dueDate: selectedDate!,
                  );
                  setState(() {
                    _terms.add(newItem);
                    _terms.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                  });
                  await _saveTerms();
                  await _scheduleNotification(newItem);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Zapisz termin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRepairDialog() {
    final titleController = TextEditingController();
    final costController = TextEditingController();
    final mileageController = TextEditingController();
    final workshopController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCar = _cars.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nowa naprawa / serwis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCar,
                  decoration: InputDecoration(
                    labelText: 'Pojazd',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _cars.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setModalState(() => selectedCar = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Nazwa naprawy (np. Wymiana klocków)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Koszt (PLN)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: mileageController,
                        decoration: InputDecoration(
                          labelText: 'Przebieg (np. 185000 km)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: workshopController,
                  decoration: InputDecoration(
                    labelText: 'Warsztat (nazwa lub adres)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      locale: const Locale('pl', 'PL'),
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month),
                        const SizedBox(width: 12),
                        Text('Data naprawy: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(selectedDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final newRepair = RepairItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      carName: selectedCar,
                      title: titleController.text.trim(),
                      cost: double.tryParse(costController.text.replaceAll(',', '.')) ?? 0.0,
                      mileage: mileageController.text.trim(),
                      workshop: workshopController.text.trim(),
                      date: selectedDate,
                    );
                    setState(() {
                      _repairs.add(newRepair);
                      _repairs.sort((a, b) => b.date.compareTo(a.date));
                    });
                    await _saveRepairs();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Zapisz naprawę', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<TermItem> filteredTerms = _selectedCarFilter == null
        ? _terms
        : _terms.where((t) => t.carName == _selectedCarFilter).toList();

    List<RepairItem> filteredRepairs = _selectedCarFilter == null
        ? _repairs
        : _repairs.where((r) => r.carName == _selectedCarFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Przypominajka', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Przełącz motyw',
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: _showManageCarsDialog,
            tooltip: 'Zarządzaj autami',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_cars.length > 1 || _selectedCarFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  const Text('Filtruj auto: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _selectedCarFilter,
                    hint: const Text('Wszystkie auta'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Wszystkie auta')),
                      ..._cars.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (val) => setState(() => _selectedCarFilter = val),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _currentIndex == 0
                ? _buildTermsView(filteredTerms)
                : _buildRepairsView(filteredRepairs),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_rounded),
            label: 'Terminarz',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_rounded),
            label: 'Naprawy',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _currentIndex == 0 ? _showAddTermDialog : _showAddRepairDialog,
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_currentIndex == 0 ? 'Dodaj termin' : 'Dodaj naprawę', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTermsView(List<TermItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available_rounded, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Brak zaplanowanych terminów', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final daysLeft = _calculateDaysLeft(item.dueDate);
        final style = _termCategories[item.title] ?? _termCategories['Inne']!;

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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: style.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: style.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('🚗 ${item.carName}${item.description.isNotEmpty ? " • ${item.description}" : ""}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(DateFormat('dd.MM.yyyy', 'pl_PL').format(item.dueDate),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final newDate = DateTime(item.dueDate.year + 1, item.dueDate.month, item.dueDate.day);
                            final updated = TermItem(
                              id: item.id,
                              carName: item.carName,
                              title: item.title,
                              description: item.description,
                              dueDate: newDate,
                            );
                            setState(() {
                              final index = _terms.indexWhere((t) => t.id == item.id);
                              if (index != -1) _terms[index] = updated;
                              _terms.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                            });
                            await _saveTerms();
                            await _scheduleNotification(updated);
                          },
                          icon: const Icon(Icons.update, size: 16),
                          label: const Text('+1 rok'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () async {
                            await flutterLocalNotificationsPlugin.cancel(item.id.hashCode);
                            setState(() => _terms.removeWhere((t) => t.id == item.id));
                            await _saveTerms();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRepairsView(List<RepairItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_rounded, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Brak zarejestrowanych napraw', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Text('${item.cost.toStringAsFixed(2)} PLN',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('🚗 ${item.carName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (item.workshop.isNotEmpty || item.mileage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.workshop.isNotEmpty) ...[
                        const Icon(Icons.store, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(item.workshop, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                      ],
                      if (item.mileage.isNotEmpty) ...[
                        const Icon(Icons.speed, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(item.mileage, style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd.MM.yyyy', 'pl_PL').format(item.date),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () async {
                        setState(() => _repairs.removeWhere((r) => r.id == item.id));
                        await _saveRepairs();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
