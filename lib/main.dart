import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  runApp(const AutoTerminApp());
}

class CarItem {
  final String name;
  final String imagePath;

  CarItem({required this.name, required this.imagePath});

  Map<String, dynamic> toMap() => {'name': name, 'imagePath': imagePath};

  factory CarItem.fromMap(Map<String, dynamic> map) => CarItem(
        name: map['name'] ?? '',
        imagePath: map['imagePath'] ?? 'suv',
      );
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
        carName: map['carName'] ?? '',
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
        carName: map['carName'] ?? '',
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

class AutoTerminApp extends StatefulWidget {
  const AutoTerminApp({super.key});

  @override
  State<AutoTerminApp> createState() => _AutoTerminAppState();
}

class _AutoTerminAppState extends State<AutoTerminApp> {
  bool _isDarkMode = true; // Domyślnie ciemny motyw

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoTermin',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pl', 'PL'),
        Locale('en', 'US'),
      ],
      locale: const Locale('pl', 'PL'),
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
  List<TermItem> _terms = [];
  List<RepairItem> _repairs = [];
  List<CarItem> _cars = [];

  final Map<String, IconData> _presetIllustrations = {
    'suv': Icons.airport_shuttle_rounded,
    'sedan': Icons.directions_car_filled_rounded,
    'sport': Icons.electric_car_rounded,
    'van': Icons.local_shipping_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String>? savedCarsJson =
        prefs.getStringList('saved_cars_objects');
    if (savedCarsJson != null) {
      _cars = savedCarsJson.map((e) => CarItem.fromMap(jsonDecode(e))).toList();
    }

    final String? termsJson = prefs.getString('saved_terms');
    if (termsJson != null) {
      final List<dynamic> decoded = jsonDecode(termsJson);
      _terms = decoded.map((e) => TermItem.fromMap(e)).toList();
    }

    final String? repairsJson = prefs.getString('saved_repairs');
    if (repairsJson != null) {
      final List<dynamic> decoded = jsonDecode(repairsJson);
      _repairs = decoded.map((e) => RepairItem.fromMap(e)).toList();
    }

    setState(() {});
  }

  Future<void> _saveCars() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = _cars.map((c) => jsonEncode(c.toMap())).toList();
    await prefs.setStringList('saved_cars_objects', listJson);
  }

  void _showAddCarDialog() {
    final customCarController = TextEditingController();
    String selectedPreset = 'suv';
    String? galleryImagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dodaj pojazd'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: customCarController,
                    decoration: InputDecoration(
                      labelText: 'Nazwa auta (np. Nissan Qashqai)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Wybierz gotową ilustrację auta:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _presetIllustrations.entries.map((entry) {
                      final isSelected = selectedPreset == entry.key &&
                          galleryImagePath == null;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          selectedPreset = entry.key;
                          galleryImagePath = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E3C72).withOpacity(0.3)
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1E3C72)
                                    : Colors.grey.shade400,
                                width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(entry.value,
                              size: 32,
                              color:
                                  isSelected ? Colors.blueAccent : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          galleryImagePath = image.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.photo_library),
                    label: Text(galleryImagePath == null
                        ? 'Dodaj zdjęcie z galerii'
                        : 'Zdjęcie wybrano ✔'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72),
                        foregroundColor: Colors.white),
                    onPressed: () {
                      final val = customCarController.text.trim();
                      if (val.isNotEmpty && !_cars.any((c) => c.name == val)) {
                        final img = galleryImagePath ?? selectedPreset;
                        setState(() {
                          _cars.add(CarItem(name: val, imagePath: img));
                        });
                        _saveCars();
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Zapisz auto'),
                  ),
                ],
              ),
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

  void _showEditCarImageDialog(int index) {
    final car = _cars[index];
    String selectedPreset = 'suv';
    String? galleryImagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Zmień grafikę: ${car.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Wybierz nową ilustrację:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _presetIllustrations.entries.map((entry) {
                      final isSelected = selectedPreset == entry.key &&
                          galleryImagePath == null;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          selectedPreset = entry.key;
                          galleryImagePath = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E3C72).withOpacity(0.3)
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1E3C72)
                                    : Colors.grey.shade400,
                                width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(entry.value,
                              size: 32,
                              color:
                                  isSelected ? Colors.blueAccent : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          galleryImagePath = image.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.photo_library),
                    label: Text(galleryImagePath == null
                        ? 'Wybierz zdjęcie z galerii'
                        : 'Zdjęcie wybrano ✔'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72),
                        foregroundColor: Colors.white),
                    onPressed: () {
                      final finalImg = galleryImagePath ?? selectedPreset;
                      setState(() {
                        _cars[index] =
                            CarItem(name: car.name, imagePath: finalImg);
                      });
                      _saveCars();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Zaktualizuj grafikę'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateDaysLeft(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final currentDateFormatted =
        DateFormat('dd.MM.yyyy', 'pl_PL').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mój Garaż',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(currentDateFormatted,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Przełącz motyw',
          ),
        ],
      ),
      body: _cars.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_outlined,
                        size: 90, color: Colors.blueGrey.shade300),
                    const SizedBox(height: 16),
                    const Text('Brak pojazdów w garażu',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Kliknij przycisk [+] poniżej, aby dodać swoje pierwsze auto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cars.length,
              itemBuilder: (context, index) {
                final car = _cars[index];
                final carTerms =
                    _terms.where((t) => t.carName == car.name).toList();
                carTerms.sort((a, b) => a.dueDate.compareTo(b.dueDate));

                String infoText = 'Brak terminów';
                Color infoColor = Colors.grey;

                if (carTerms.isNotEmpty) {
                  final nextTerm = carTerms.first;
                  final days = _calculateDaysLeft(nextTerm.dueDate);
                  if (days < 0) {
                    infoText =
                        '${nextTerm.title}: Po terminie o ${days.abs()} dni!';
                    infoColor = Colors.red;
                  } else if (days == 0) {
                    infoText = '${nextTerm.title}: Dzisiaj!';
                    infoColor = Colors.red;
                  } else {
                    infoText =
                        '${nextTerm.title}: za $days dni (${DateFormat('dd.MM.yyyy', 'pl_PL').format(nextTerm.dueDate)})';
                    infoColor = days <= 14 ? Colors.orange : Colors.green;
                  }
                  if (carTerms.length > 1) {
                    infoText += ' (+${carTerms.length - 1} inne)';
                  }
                }

                Widget imageWidget;
                if (_presetIllustrations.containsKey(car.imagePath)) {
                  imageWidget = Container(
                    color: const Color(0xFF1E3C72).withOpacity(0.8),
                    child: Center(
                      child: Icon(_presetIllustrations[car.imagePath],
                          size: 70, color: Colors.white),
                    ),
                  );
                } else {
                  imageWidget = Image.file(
                    File(car.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1E3C72),
                      child: const Icon(Icons.directions_car,
                          size: 70, color: Colors.white),
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CarDetailScreen(
                              carName: car.name,
                              carImageUrl: car.imagePath,
                              presetMap: _presetIllustrations),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 150,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageWidget,
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.6)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 16,
                                right: 16,
                                child: Text(
                                  car.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 4)
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.notifications_active,
                                        size: 16, color: Colors.blueGrey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        infoText,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: infoColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Colors.blue),
                                    tooltip: 'Zmień grafikę auta',
                                    onPressed: () =>
                                        _showEditCarImageDialog(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    tooltip: 'Usuń auto',
                                    onPressed: () {
                                      setState(() => _cars.removeAt(index));
                                      _saveCars();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCarDialog,
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj auto',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class CarDetailScreen extends StatefulWidget {
  final String carName;
  final String carImageUrl;
  final Map<String, IconData> presetMap;
  const CarDetailScreen(
      {super.key,
      required this.carName,
      required this.carImageUrl,
      required this.presetMap});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  int _currentIndex = 0;
  List<TermItem> _terms = [];
  List<RepairItem> _repairs = [];

  final Map<String, CategoryStyle> _termCategories = {
    'Badanie techniczne':
        CategoryStyle(Icons.fact_check_rounded, const Color(0xFF1976D2)),
    'Polisa OC/AC':
        CategoryStyle(Icons.shield_rounded, const Color(0xFF512DA8)),
    'Wymiana oleju/filtrów':
        CategoryStyle(Icons.build_circle_rounded, const Color(0xFFE65100)),
    'Wymiana opon': CategoryStyle(Icons.album_rounded, const Color(0xFF00796B)),
    'Klimatyzacja / Serwis':
        CategoryStyle(Icons.ac_unit_rounded, const Color(0xFF0288D1)),
    'Inne': CategoryStyle(
        Icons.directions_car_filled_rounded, const Color(0xFF455A64)),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? termsJson = prefs.getString('saved_terms');
    if (termsJson != null) {
      final List<dynamic> decoded = jsonDecode(termsJson);
      _terms = decoded
          .map((e) => TermItem.fromMap(e))
          .where((t) => t.carName == widget.carName)
          .toList();
      _terms.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }

    final String? repairsJson = prefs.getString('saved_repairs');
    if (repairsJson != null) {
      final List<dynamic> decoded = jsonDecode(repairsJson);
      _repairs = decoded
          .map((e) => RepairItem.fromMap(e))
          .where((r) => r.carName == widget.carName)
          .toList();
      _repairs.sort((a, b) => b.date.compareTo(a.date));
    }

    setState(() {});
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();

    final String? termsJson = prefs.getString('saved_terms');
    List<TermItem> allTerms = [];
    if (termsJson != null) {
      allTerms = (jsonDecode(termsJson) as List)
          .map((e) => TermItem.fromMap(e))
          .where((t) => t.carName != widget.carName)
          .toList();
    }
    allTerms.addAll(_terms);
    await prefs.setString(
        'saved_terms', jsonEncode(allTerms.map((e) => e.toMap()).toList()));

    final String? repairsJson = prefs.getString('saved_repairs');
    List<RepairItem> allRepairs = [];
    if (repairsJson != null) {
      allRepairs = (jsonDecode(repairsJson) as List)
          .map((e) => RepairItem.fromMap(e))
          .where((r) => r.carName != widget.carName)
          .toList();
    }
    allRepairs.addAll(_repairs);
    await prefs.setString(
        'saved_repairs', jsonEncode(allRepairs.map((e) => e.toMap()).toList()));
  }

  int _calculateDaysLeft(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  Future<void> _scheduleNotification(TermItem item) async {
    DateTime reminderDate = item.dueDate.subtract(const Duration(days: 7));
    reminderDate =
        DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 9, 0);

    if (reminderDate.isBefore(DateTime.now())) {
      reminderDate = DateTime.now().add(const Duration(seconds: 15));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      item.id.hashCode,
      'Zbliża się termin: ${item.title} (${widget.carName})',
      'Upływa: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(item.dueDate)} ${item.description.isNotEmpty ? "(${item.description})" : ""}',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'przypominajka_channel',
          'Przypomnienia o terminach',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<DateTime?> _pickPolishDate(DateTime initialDate) async {
    return await showDatePicker(
      context: context,
      locale: const Locale('pl', 'PL'),
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  void _showAddTermDialog() {
    final descController = TextEditingController();
    DateTime? selectedDate;
    String selectedCategory = _termCategories.keys.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              const Text('Nowy termin',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _termCategories.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon,
                            color: entry.value.color, size: 20),
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
                  labelText: 'Dodatkowy opis',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await _pickPolishDate(
                      DateTime.now().add(const Duration(days: 30)));
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
                            fontWeight: selectedDate == null
                                ? FontWeight.normal
                                : FontWeight.bold),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (selectedDate == null) return;
                  final newItem = TermItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    carName: widget.carName,
                    title: selectedCategory,
                    description: descController.text.trim(),
                    dueDate: selectedDate!,
                  );
                  setState(() {
                    _terms.add(newItem);
                    _terms.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                  });
                  await _saveAll();
                  await _scheduleNotification(newItem);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Zapisz termin',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                const Text('Nowa naprawa / serwis',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Nazwa naprawy (np. Wymiana klocków)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: mileageController,
                        decoration: InputDecoration(
                          labelText: 'Przebieg',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await _pickPolishDate(selectedDate);
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
                            'Data: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(selectedDate)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final newRepair = RepairItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      carName: widget.carName,
                      title: titleController.text.trim(),
                      cost: double.tryParse(
                              costController.text.replaceAll(',', '.')) ??
                          0.0,
                      mileage: mileageController.text.trim(),
                      workshop: workshopController.text.trim(),
                      date: selectedDate,
                    );
                    setState(() {
                      _repairs.add(newRepair);
                      _repairs.sort((a, b) => b.date.compareTo(a.date));
                    });
                    await _saveAll();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Zapisz naprawę',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    Widget headerWidget;
    if (widget.presetMap.containsKey(widget.carImageUrl)) {
      headerWidget = Container(
        color: const Color(0xFF1E3C72),
        child: Center(
          child: Icon(widget.presetMap[widget.carImageUrl],
              size: 90, color: Colors.white),
        ),
      );
    } else {
      headerWidget = Image.file(
        File(widget.carImageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1E3C72),
          child:
              const Icon(Icons.directions_car, size: 90, color: Colors.white),
        ),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            centerTitle: true,
            backgroundColor: const Color(0xFF1E3C72),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.carName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  headerWidget,
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: _currentIndex == 0 ? _buildTermsView() : _buildRepairsView(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.event_note_rounded), label: 'Terminarz'),
          NavigationDestination(
              icon: Icon(Icons.build_rounded), label: 'Naprawy'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _currentIndex == 0 ? _showAddTermDialog : _showAddRepairDialog,
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_currentIndex == 0 ? 'Dodaj termin' : 'Dodaj naprawę',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTermsView() {
    if (_terms.isEmpty) {
      return const Center(
          child: Text('Brak zaplanowanych terminów dla tego auta',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _terms.length,
      itemBuilder: (ctx, i) {
        final item = _terms[i];
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
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(style.icon, color: style.color, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          if (item.description.isNotEmpty)
                            Text(item.description,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Data: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(item.dueDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final newDate = DateTime(item.dueDate.year + 1,
                                item.dueDate.month, item.dueDate.day);
                            final updated = TermItem(
                              id: item.id,
                              carName: item.carName,
                              title: item.title,
                              description: item.description,
                              dueDate: newDate,
                            );
                            setState(() {
                              _terms[i] = updated;
                              _terms.sort(
                                  (a, b) => a.dueDate.compareTo(b.dueDate));
                            });
                            await _saveAll();
                            await _scheduleNotification(updated);
                          },
                          icon: const Icon(Icons.update, size: 16),
                          label: const Text('+1 rok'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () async {
                            await flutterLocalNotificationsPlugin
                                .cancel(item.id.hashCode);
                            setState(() => _terms.removeAt(i));
                            await _saveAll();
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

  Widget _buildRepairsView() {
    if (_repairs.isEmpty) {
      return const Center(
          child: Text('Brak zarejestrowanych napraw dla tego auta',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _repairs.length,
      itemBuilder: (ctx, i) {
        final item = _repairs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${item.cost.toStringAsFixed(2)} PLN',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
                if (item.workshop.isNotEmpty || item.mileage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                      '${item.workshop.isNotEmpty ? "Warsztat: ${item.workshop}" : ""} ${item.mileage.isNotEmpty ? "• ${item.mileage}" : ""}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd.MM.yyyy', 'pl_PL').format(item.date),
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        setState(() => _repairs.removeAt(i));
                        await _saveAll();
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
