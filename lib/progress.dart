import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:paceo/dashboard.dart';

class ProgressSection extends StatefulWidget {
  const ProgressSection({super.key});

  @override
  State<ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<ProgressSection> {
  bool isWeekly = true;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  // Controllers for body measurements
  final TextEditingController weightController = TextEditingController();
  final TextEditingController chestController = TextEditingController();
  final TextEditingController waistController = TextEditingController();
  final TextEditingController hipsController = TextEditingController();
  final TextEditingController armsController = TextEditingController();
  final TextEditingController thighsController = TextEditingController();
  final TextEditingController bodyFatController = TextEditingController();
  final TextEditingController bicepsController = TextEditingController();
  final TextEditingController calvesController = TextEditingController();
  final TextEditingController shouldersController = TextEditingController();
  
  // Controllers for daily activities
  final TextEditingController stepsController = TextEditingController();
  final TextEditingController waterController = TextEditingController();
  final TextEditingController sleepController = TextEditingController();
  
  bool _isSaving = false;
  List<FlSpot> _chartSpots = [];
  List<DateTime> _spotDates = [];
  double _minY = 0;
  double _maxY = 100;
  bool _isLoadingChart = false;
  DateTime? _lastRefreshTime;
  List<Map<String, dynamic>> _recentMeasurements = [];
  List<Map<String, dynamic>> _recentActivities = [];
  
  // Selection mode for deletion
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};
  
  // Delete loading state
  bool _isDeleting = false;
  
  // Filter options
  String _selectedFilterType = "All Types";
  String _selectedFilterDate = "All Dates";
  
  List<String> _filterTypes = ["All Types"];
  List<String> _filterDates = ["All Dates"];
  
  // Tab selection
  int _selectedTab = 0;
  final List<String> _tabs = ["Body Measurements", "Daily Activities"];
  
  // Which measurement type to display in chart
  String _selectedMeasurementType = "Weight";
  final List<String> _measurementTypes = [
    "Weight", 
    "Chest", 
    "Waist", 
    "Hips", 
    "Body Fat %",
    "Arms",
    "Thighs",
    "Biceps",
    "Calves",
    "Shoulders",
    "Steps",
    "Water",
    "Sleep"
  ];

  // Daily activity types
  final List<String> _activityTypes = ["Steps", "Water", "Sleep"];
  
  // Measurement units
  final Map<String, String> _measurementUnits = {
    "Weight": "kg",
    "Chest": "inches",
    "Waist": "inches",
    "Hips": "inches",
    "Body Fat %": "%",
    "Arms": "inches",
    "Thighs": "inches",
    "Biceps": "inches",
    "Calves": "inches",
    "Shoulders": "inches",
    "Steps": "steps",
    "Water": "L",
    "Sleep": "hours"
  };

  // Icons for each measurement
  final Map<String, IconData> _measurementIcons = {
    "Weight": Icons.monitor_weight,
    "Chest": Icons.straighten,
    "Waist": Icons.circle,
    "Hips": Icons.woman,
    "Body Fat %": Icons.pie_chart,
    "Arms": Icons.fitness_center,
    "Thighs": Icons.directions_run,
    "Biceps": Icons.album,
    "Calves": Icons.directions_walk,
    "Shoulders": Icons.accessibility_new,
    "Steps": Icons.directions_walk,
    "Water": Icons.water_drop,
    "Sleep": Icons.bedtime,
  };

  // Default goals
  double _stepsGoal = 10000;
  double _waterGoal = 2.5;
  double _sleepGoal = 8.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserGoals();
      _loadChartData();
      _loadRecentMeasurements();
      _loadRecentActivities();
    });
  }

  @override
  void dispose() {
    // Dispose body measurement controllers
    weightController.dispose();
    chestController.dispose();
    waistController.dispose();
    hipsController.dispose();
    armsController.dispose();
    thighsController.dispose();
    bodyFatController.dispose();
    bicepsController.dispose();
    calvesController.dispose();
    shouldersController.dispose();
    
    // Dispose activity controllers
    stepsController.dispose();
    waterController.dispose();
    sleepController.dispose();
    
    super.dispose();
  }

  Future<void> _loadUserGoals() async {
    if (user == null) return;
    
    try {
      final doc = await firestore
          .collection("users")
          .doc(user!.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _stepsGoal = (data["stepsGoal"] ?? 10000).toDouble();
          _waterGoal = (data["waterGoal"] ?? 2.5).toDouble();
          _sleepGoal = (data["sleepGoal"] ?? 8.0).toDouble();
        });
      }
    } catch (e) {
      print("Error loading user goals: $e");
    }
  }

  Future<void> _loadChartData() async {
  if (user == null) return;

  setState(() {
    _isLoadingChart = true;
  });

  try {
    print("Loading chart data for user: ${user!.uid}");
    
    // Load data based on selected type
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = [];
    
    if (_selectedMeasurementType == "Steps" || 
        _selectedMeasurementType == "Water" || 
        _selectedMeasurementType == "Sleep") {
      // Load from respective collections for daily activities
      final collectionName = _getCollectionName(_selectedMeasurementType);
      final snapshot = await firestore
          .collection(collectionName)
          .where("userId", isEqualTo: user!.uid)
          .get();
      
      filteredDocs = snapshot.docs;
    } else {
      // Load from trackprogress for body measurements
      final snapshot = await firestore
          .collection('trackprogress')
          .where("userId", isEqualTo: user!.uid)
          .get();

      filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final type = data['type']?.toString() ?? '';
        return type == _selectedMeasurementType;
      }).toList();
    }

    print("$_selectedMeasurementType documents found: ${filteredDocs.length}");
    
    if (filteredDocs.isEmpty) {
      print("No $_selectedMeasurementType data found");
      setState(() {
        _chartSpots = [];
        _spotDates = [];
        _minY = _getDefaultMinY(_selectedMeasurementType);
        _maxY = _getDefaultMaxY(_selectedMeasurementType);
        _isLoadingChart = false;
        _lastRefreshTime = DateTime.now();
      });
      return;
    }

    // Parse data and sort locally
    final logs = <Map<String, dynamic>>[];
    for (final doc in filteredDocs) {
      try {
        final data = doc.data();
        
        if (_selectedMeasurementType == "Steps" || 
            _selectedMeasurementType == "Water" || 
            _selectedMeasurementType == "Sleep") {
          final dateStr = data['date']?.toString() ?? '';
          final value = _getActivityValue(data, _selectedMeasurementType);
          final timestamp = data['timestamp'] as Timestamp?;
          
          if (dateStr.isEmpty || value == null) continue;
          
          final date = _parseDate(dateStr);
          if (date == null) continue;
          
          logs.add({
            'value': value.toDouble(),
            'date': date,
            'timestamp': timestamp?.millisecondsSinceEpoch ?? date.millisecondsSinceEpoch,
            'dateStr': dateStr,
          });
        } else {
          final dateStr = data['date']?.toString() ?? '';
          final value = data['value'];
          final timestamp = data['timestamp'] as Timestamp?;
          
          if (dateStr.isEmpty || value == null) continue;
          
          final date = _parseDate(dateStr);
          if (date == null) continue;
          
          logs.add({
            'value': value is int ? value.toDouble() : (value as num).toDouble(),
            'date': date,
            'timestamp': timestamp?.millisecondsSinceEpoch ?? date.millisecondsSinceEpoch,
            'dateStr': dateStr,
          });
        }
        
        print("Loaded $_selectedMeasurementType: ${logs.last['value']} on ${logs.last['dateStr']}");
      } catch (e) {
        print("Error parsing document: $e");
      }
    }

    // Sort by date (or timestamp if available)
    logs.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

    if (logs.isEmpty) {
      setState(() {
        _chartSpots = [];
        _spotDates = [];
        _minY = _getDefaultMinY(_selectedMeasurementType);
        _maxY = _getDefaultMaxY(_selectedMeasurementType);
        _isLoadingChart = false;
        _lastRefreshTime = DateTime.now();
      });
      return;
    }

    // Create chart data
    final spots = <FlSpot>[];
    final dates = <DateTime>[];
    
    for (int i = 0; i < logs.length; i++) {
      final value = logs[i]['value'] as double;
      final date = logs[i]['date'] as DateTime;
      spots.add(FlSpot(i.toDouble(), value));
      dates.add(date);
    }

    final allValues = spots.map((e) => e.y).toList();
    final minVal = allValues.reduce((a, b) => a < b ? a : b);
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    
    // Add some padding to Y axis
    final yPadding = (maxVal - minVal) * 0.2;
    
    setState(() {
      _chartSpots = spots;
      _spotDates = dates;
      _minY = (minVal - yPadding).clamp(minVal - _getYPadding(_selectedMeasurementType), minVal - 1);
      _maxY = (maxVal + yPadding).clamp(maxVal + 1, maxVal + _getYPadding(_selectedMeasurementType));
      _isLoadingChart = false;
      _lastRefreshTime = DateTime.now();
    });
    
    print("Chart loaded with ${spots.length} points");
    print("Y range: $_minY to $_maxY");
  } catch (e, stack) {
    print("Error loading chart data: $e");
    print("Stack trace: $stack");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error loading chart: $e"), backgroundColor: Colors.red),
    );
    setState(() {
      _isLoadingChart = false;
    });
  }
}

 Future<void> _loadRecentMeasurements() async {
  if (user == null) return;

  try {
    // Remove orderBy to avoid index requirement, we'll sort locally
    final snapshot = await firestore
        .collection('trackprogress')
        .where("userId", isEqualTo: user!.uid)
        .get();

    final measurements = <Map<String, dynamic>>[];
    final typesSet = <String>{};
    final datesSet = <String>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final docId = doc.id;
      final type = data['type']?.toString() ?? '';
      final date = data['date']?.toString() ?? '';
      
      measurements.add({
        'id': docId,
        'date': date,
        'type': type,
        'value': data['value']?.toString() ?? '',
        'unit': data['unit'] ?? '',
        'timestamp': (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        'isSelected': false,
      });
      
      if (type.isNotEmpty) typesSet.add(type);
      if (date.isNotEmpty) datesSet.add(date);
    }

    // Sort by timestamp descending locally
    measurements.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    
    // Take only last 20
    final recentMeasurements = measurements.take(20).toList();

    // Update filter lists
    final sortedDates = datesSet.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort dates descending
    
    setState(() {
      _recentMeasurements = recentMeasurements;
      _filterTypes = ["All Types", ...typesSet.toList()..sort()];
      _filterDates = ["All Dates", ...sortedDates];
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  } catch (e) {
    print("Error loading recent measurements: $e");
  }
}

  Future<void> _loadRecentActivities() async {
  if (user == null) return;

  try {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekAgoStr = DateFormat('yyyy-MM-dd').format(weekAgo);
    
    // Load recent steps - Remove orderBy for now to avoid index requirement
    final stepsSnapshot = await firestore
        .collection('daily_stats')
        .where("userId", isEqualTo: user!.uid)
        .get();
    
    // Load recent water intake
    final waterSnapshot = await firestore
        .collection('water_intake')
        .where("userId", isEqualTo: user!.uid)
        .get();
    
    // Load recent sleep
    final sleepSnapshot = await firestore
        .collection('sleep_tracking')
        .where("userId", isEqualTo: user!.uid)
        .get();

    final activities = <Map<String, dynamic>>[];
    
    // Add steps activities and filter locally by date
    for (final doc in stepsSnapshot.docs) {
      final data = doc.data();
      final dateStr = data['date']?.toString() ?? '';
      
      // Filter by date locally
      if (dateStr.compareTo(weekAgoStr) >= 0) {
        activities.add({
          'type': 'Steps',
          'date': dateStr,
          'value': data['steps']?.toString() ?? '0',
          'unit': 'steps',
          'timestamp': (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }
    }
    
    // Add water activities and filter locally by date
    for (final doc in waterSnapshot.docs) {
      final data = doc.data();
      final dateStr = data['date']?.toString() ?? '';
      
      // Filter by date locally
      if (dateStr.compareTo(weekAgoStr) >= 0) {
        activities.add({
          'type': 'Water',
          'date': dateStr,
          'value': data['amount']?.toString() ?? '0',
          'unit': 'L',
          'timestamp': (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }
    }
    
    // Add sleep activities and filter locally by date
    for (final doc in sleepSnapshot.docs) {
      final data = doc.data();
      final dateStr = data['date']?.toString() ?? '';
      
      // Filter by date locally
      if (dateStr.compareTo(weekAgoStr) >= 0) {
        activities.add({
          'type': 'Sleep',
          'date': dateStr,
          'value': data['hours']?.toString() ?? '0',
          'unit': 'hours',
          'timestamp': (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }
    }

    // Sort by timestamp descending
    activities.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    
    setState(() {
      _recentActivities = activities.take(10).toList();
    });
  } catch (e) {
    print("Error loading recent activities: $e");
  }
}

  Future<void> _saveAllMeasurements() async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedTab == 0) {
      // Save body measurements
      await _saveBodyMeasurements();
    } else {
      // Save daily activities
      await _saveDailyActivities();
    }
  }

  Future<void> _saveBodyMeasurements() async {
    // Collect all values
    final measurements = <Map<String, dynamic>>[
      {"type": "Weight", "value": double.tryParse(weightController.text), "controller": weightController},
      {"type": "Chest", "value": double.tryParse(chestController.text), "controller": chestController},
      {"type": "Waist", "value": double.tryParse(waistController.text), "controller": waistController},
      {"type": "Hips", "value": double.tryParse(hipsController.text), "controller": hipsController},
      {"type": "Arms", "value": double.tryParse(armsController.text), "controller": armsController},
      {"type": "Thighs", "value": double.tryParse(thighsController.text), "controller": thighsController},
      {"type": "Body Fat %", "value": double.tryParse(bodyFatController.text), "controller": bodyFatController},
      {"type": "Biceps", "value": double.tryParse(bicepsController.text), "controller": bicepsController},
      {"type": "Calves", "value": double.tryParse(calvesController.text), "controller": calvesController},
      {"type": "Shoulders", "value": double.tryParse(shouldersController.text), "controller": shouldersController},
    ];

    // Check if at least one measurement is entered
    final hasValidMeasurement = measurements.any((m) => m["value"] != null);
    if (!hasValidMeasurement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one measurement")),
      );
      return;
    }

    // Validate ranges
    for (final measurement in measurements) {
      final value = measurement["value"] as double?;
      final type = measurement["type"] as String;
      
      if (value != null) {
        switch (type) {
          case "Weight":
            if (value < 20 || value > 300) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please enter a valid weight (20-300 kg)"), backgroundColor: Colors.red),
              );
              return;
            }
            break;
          case "Body Fat %":
            if (value < 3 || value > 60) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please enter a valid body fat percentage (3-60%)"), backgroundColor: Colors.red),
              );
              return;
            }
            break;
          default: // For all circumference measurements
            if (value < 5 || value > 200) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Please enter a valid $type measurement (5-200 inches)"), backgroundColor: Colors.red),
              );
              return;
            }
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final timestamp = Timestamp.now();

      List<String> savedTypes = [];
      
      // Save each measurement that has a value
      for (final measurement in measurements) {
        final type = measurement["type"] as String;
        final value = measurement["value"] as double?;
        final controller = measurement["controller"] as TextEditingController;
        
        if (value != null) {
          await firestore.collection('trackprogress').add({
            "userId": user!.uid,
            "date": todayStr,
            "type": type,
            "value": value,
            "unit": _measurementUnits[type],
            "timestamp": timestamp,
            "createdAt": DateTime.now().toIso8601String(),
          });
          
          print("Saved $type: $value ${_measurementUnits[type]}");
          savedTypes.add(type);
          controller.clear();
        }
      }

      // Wait a moment for Firestore to process the write
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload all data
      await _loadChartData();
      await _loadRecentMeasurements();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${savedTypes.length} measurement${savedTypes.length > 1 ? 's' : ''} saved successfully!",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error saving measurements: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveDailyActivities() async {
    final steps = int.tryParse(stepsController.text);
    final water = double.tryParse(waterController.text);
    final sleep = double.tryParse(sleepController.text);

    // Check if at least one activity is entered
    if (steps == null && water == null && sleep == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one activity")),
      );
      return;
    }

    // Validate ranges
    if (steps != null && (steps < 0 || steps > 50000)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid steps (0-50,000)"), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (water != null && (water < 0 || water > 20)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid water intake (0-20 L)"), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (sleep != null && (sleep < 0 || sleep > 24)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid sleep hours (0-24)"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final timestamp = Timestamp.now();

      List<String> savedActivities = [];
      
      // Save steps if entered
      if (steps != null) {
        await firestore
            .collection('daily_stats')
            .doc('${user!.uid}_$todayStr')
            .set({
              'userId': user!.uid,
              'date': todayStr,
              'steps': steps,
              'timestamp': timestamp,
              'createdAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
        
        savedActivities.add("Steps");
        stepsController.clear();
      }
      
      // Save water if entered
      if (water != null) {
        await firestore
            .collection('water_intake')
            .doc('${user!.uid}_$todayStr')
            .set({
              'userId': user!.uid,
              'date': todayStr,
              'amount': water,
              'timestamp': timestamp,
              'createdAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
        
        savedActivities.add("Water");
        waterController.clear();
      }
      
      // Save sleep if entered
      if (sleep != null) {
        await firestore
            .collection('sleep_tracking')
            .doc('${user!.uid}_$todayStr')
            .set({
              'userId': user!.uid,
              'date': todayStr,
              'hours': sleep,
              'timestamp': timestamp,
              'createdAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
        
        savedActivities.add("Sleep");
        sleepController.clear();
      }

      // Wait a moment for Firestore to process the write
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload all data
      await _loadChartData();
      await _loadRecentActivities();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${savedActivities.length} activit${savedActivities.length > 1 ? 'ies' : 'y'} saved successfully!",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error saving activities: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // DELETE FUNCTIONALITY
  Future<void> _deleteSelectedMeasurements() async {
    if (user == null || _selectedIds.isEmpty) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Delete each selected document
      for (final docId in _selectedIds) {
        await firestore.collection('trackprogress').doc(docId).delete();
      }

      // Clear selection and reload data
      _selectedIds.clear();
      await _loadChartData();
      await _loadRecentMeasurements();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deleted ${_selectedIds.length} measurement${_selectedIds.length > 1 ? 's' : ''}"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error deleting measurements: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isDeleting = false;
        _isSelectionMode = false;
      });
    }
  }

  Future<void> _deleteAllMeasurements() async {
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Measurements"),
        content: const Text("Are you sure you want to delete ALL your measurements? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Get all user's measurements
      final snapshot = await firestore
          .collection('trackprogress')
          .where("userId", isEqualTo: user!.uid)
          .get();

      // Delete all documents
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Clear all data
      await _loadChartData();
      await _loadRecentMeasurements();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All measurements deleted"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error deleting all measurements: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _deleteMeasurementsByType(String type) async {
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete All $type Measurements"),
        content: Text("Are you sure you want to delete ALL your $type measurements?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Get all user's measurements of this type
      final snapshot = await firestore
          .collection('trackprogress')
          .where("userId", isEqualTo: user!.uid)
          .where("type", isEqualTo: type)
          .get();

      // Delete all documents
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Reload data
      await _loadChartData();
      await _loadRecentMeasurements();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("All $type measurements deleted"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error deleting measurements by type: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _deleteMeasurementsByDate(String date) async {
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Measurements from $date"),
        content: Text("Are you sure you want to delete ALL measurements from $date?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Get all user's measurements from this date
      final snapshot = await firestore
          .collection('trackprogress')
          .where("userId", isEqualTo: user!.uid)
          .where("date", isEqualTo: date)
          .get();

      // Delete all documents
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Reload data
      await _loadChartData();
      await _loadRecentMeasurements();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Measurements from $date deleted"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error deleting measurements by date: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
      } else {
        _selectedIds.add(docId);
      }
      
      // Exit selection mode if nothing is selected
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      // Filter measurements based on current filters
      final filteredMeasurements = _getFilteredMeasurements();
      _selectedIds = filteredMeasurements.map((m) => m['id'] as String).toSet();
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredMeasurements() {
    return _recentMeasurements.where((measurement) {
      final type = measurement['type'] as String;
      final date = measurement['date'] as String;
      
      final typeMatches = _selectedFilterType == "All Types" || type == _selectedFilterType;
      final dateMatches = _selectedFilterDate == "All Dates" || date == _selectedFilterDate;
      
      return typeMatches && dateMatches;
    }).toList();
  }

  // Helper methods
  String _getCollectionName(String type) {
    switch (type) {
      case "Steps": return "daily_stats";
      case "Water": return "water_intake";
      case "Sleep": return "sleep_tracking";
      default: return "trackprogress";
    }
  }

  dynamic _getActivityValue(Map<String, dynamic> data, String type) {
    switch (type) {
      case "Steps": return data['steps'];
      case "Water": return data['amount'];
      case "Sleep": return data['hours'];
      default: return data['value'];
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) return null;
      
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
    } catch (e) {
      return null;
    }
  }

  double _getDefaultMinY(String type) {
    switch (type) {
      case "Weight": return 50;
      case "Body Fat %": return 5;
      case "Steps": return 0;
      case "Water": return 0;
      case "Sleep": return 0;
      default: return 20;
    }
  }

  double _getDefaultMaxY(String type) {
    switch (type) {
      case "Weight": return 100;
      case "Body Fat %": return 40;
      case "Steps": return 15000;
      case "Water": return 5;
      case "Sleep": return 12;
      default: return 60;
    }
  }

  double _getYPadding(String type) {
    switch (type) {
      case "Weight": return 10;
      case "Body Fat %": return 5;
      case "Steps": return 2000;
      case "Water": return 0.5;
      case "Sleep": return 1;
      default: return 5;
    }
  }

  Widget _buildChart() {
    if (_isLoadingChart) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chartSpots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_measurementIcons[_selectedMeasurementType] ?? Icons.analytics_outlined, 
                size: 50, color: Colors.grey),
            const SizedBox(height: 10),
            Text("No $_selectedMeasurementType data available", 
                style: const TextStyle(color: Colors.grey)),
            Text("Add your first $_selectedMeasurementType measurement below", 
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return LineChart(
      LineChartData(
        minY: _minY,
        maxY: _maxY,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text("${value.toStringAsFixed(_selectedMeasurementType == "Weight" ? 1 : 0)}${_measurementUnits[_selectedMeasurementType]}",
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
              reservedSize: 40,
              interval: (_maxY - _minY) / 5,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _spotDates.length <= 8,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _spotDates.length) return const SizedBox();
                final date = _spotDates[index];
                
                // Show every 2nd label if too many points
                if (_spotDates.length > 8 && index % 2 != 0) return const SizedBox();
                
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("${date.day}/${date.month}",
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.spotIndex;
                if (index < 0 || index >= _spotDates.length) return null;
                
                return LineTooltipItem(
                  '${_spotDates[index].day}/${_spotDates[index].month}/${_spotDates[index].year}\n${touchedSpot.y.toStringAsFixed(_selectedMeasurementType == "Weight" ? 1 : 0)} ${_measurementUnits[_selectedMeasurementType]}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _chartSpots,
            isCurved: true,
            color: const Color(0xFF9E1818),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9E1818).withOpacity(0.3),
                  const Color(0xFF9E1818).withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF9E1818),
                );
              },
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFF9E1818), Color(0xFFAA1308)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementSelector() {
    // Filter measurement types based on selected tab
    List<String> availableTypes = _selectedTab == 0 
        ? _measurementTypes.take(10).toList() // Body measurements only
        : _measurementTypes.sublist(10); // Daily activities only
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Measurement Type",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableTypes.map((type) {
                final isSelected = _selectedMeasurementType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedMeasurementType = type;
                        });
                        _loadChartData();
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF9E1818),
                    labelStyle: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : const Color(0xFF4A1818),
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF9E1818) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                  // Update measurement type based on tab
                  if (index == 0 && !_measurementTypes.take(10).contains(_selectedMeasurementType)) {
                    _selectedMeasurementType = "Weight";
                  } else if (index == 1 && !_measurementTypes.sublist(10).contains(_selectedMeasurementType)) {
                    _selectedMeasurementType = "Steps";
                  }
                  _loadChartData();
                });
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF9E1818).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF9E1818) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[index],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF8B2E2E) : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBodyMeasurementsInput() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildCompactInputField("Weight", "kg", weightController),
        _buildCompactInputField("Chest", "inches", chestController),
        _buildCompactInputField("Waist", "inches", waistController),
        _buildCompactInputField("Hips", "inches", hipsController),
        _buildCompactInputField("Arms", "inches", armsController),
        _buildCompactInputField("Thighs", "inches", thighsController),
        _buildCompactInputField("Body Fat %", "%", bodyFatController),
        _buildCompactInputField("Biceps", "inches", bicepsController),
        _buildCompactInputField("Calves", "inches", calvesController),
        _buildCompactInputField("Shoulders", "inches", shouldersController),
      ],
    );
  }

  Widget _buildDailyActivitiesInput() {
    return Column(
      children: [
        _buildActivityInputField("Steps", "steps", stepsController, _stepsGoal),
        const SizedBox(height: 15),
        _buildActivityInputField("Water", "L", waterController, _waterGoal),
        const SizedBox(height: 15),
        _buildActivityInputField("Sleep", "hours", sleepController, _sleepGoal),
        const SizedBox(height: 20),
        _buildQuickAddButtons(),
      ],
    );
  }

  Widget _buildActivityInputField(String label, String unit, TextEditingController controller, double goal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_measurementIcons[label] ?? Icons.straighten,
                        size: 18, color: const Color(0xFF9E1818)),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4A1818),
                      ),
                    ),
                  ],
                ),
                Text(
                  "Goal: ${goal.toStringAsFixed(label == "Steps" ? 0 : 1)} $unit",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: label != "Steps"),
            decoration: InputDecoration(
              hintText: "Enter $label",
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixText: unit,
              suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Add",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4A1818),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildQuickAddButton("Water", "250ml", 0.25, waterController),
            _buildQuickAddButton("Water", "500ml", 0.5, waterController),
            _buildQuickAddButton("Water", "1L", 1.0, waterController),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddButton(String type, String label, double amount, TextEditingController controller) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            final currentValue = double.tryParse(controller.text) ?? 0;
            controller.text = (currentValue + amount).toString();
          },
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue.withOpacity(0.1),
          ),
          child: Icon(
            _measurementIcons[type],
            color: Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInputField(String label, String unit, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixText: unit,
          suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          prefixIcon: Icon(
            _measurementIcons[label] ?? Icons.straighten,
            size: 18,
            color: const Color(0xFF9E1818),
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildDeleteMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.delete_outline, color: Color(0xFF9E1818)),
      onSelected: (value) async {
        switch (value) {
          case 'delete_selected':
            if (_selectedIds.isNotEmpty) {
              await _deleteSelectedMeasurements();
            }
            break;
          case 'delete_by_type':
            _showTypeSelectionDialog();
            break;
          case 'delete_by_date':
            _showDateSelectionDialog();
            break;
          case 'delete_all':
            await _deleteAllMeasurements();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'delete_selected',
          enabled: _selectedIds.isNotEmpty,
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20),
              const SizedBox(width: 10),
              Text("Delete Selected (${_selectedIds.length})"),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete_by_type',
          child: Row(
            children: [
              Icon(Icons.category_outlined, size: 20),
              SizedBox(width: 10),
              Text("Delete by Type"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete_by_date',
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20),
              SizedBox(width: 10),
              Text("Delete by Date"),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete_all',
          child: Row(
            children: [
              Icon(Icons.delete_forever, size: 20, color: Colors.red),
              const SizedBox(width: 10),
              Text("Delete All", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showTypeSelectionDialog() {
    final availableTypes = _filterTypes.where((type) => type != "All Types").toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Type to Delete"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTypes.length,
            itemBuilder: (context, index) {
              final type = availableTypes[index];
              return ListTile(
                leading: Icon(_measurementIcons[type] ?? Icons.straighten),
                title: Text(type),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteMeasurementsByType(type);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showDateSelectionDialog() {
    final availableDates = _filterDates.where((date) => date != "All Dates").toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Date to Delete"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableDates.length,
            itemBuilder: (context, index) {
              final date = availableDates[index];
              return ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(date),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteMeasurementsByDate(date);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Filter History",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilterType,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _filterTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              if (type != "All Types")
                                Icon(_measurementIcons[type] ?? Icons.straighten, size: 18),
                              const SizedBox(width: 8),
                              Text(type),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilterType = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilterDate,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _filterDates.map((date) {
                        return DropdownMenuItem(
                          value: date,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18),
                              const SizedBox(width: 8),
                              Text(date),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilterDate = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionControls() {
    if (!_isSelectionMode) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1818).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9E1818).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearSelection,
            color: const Color(0xFF9E1818),
          ),
          Expanded(
            child: Text(
              "${_selectedIds.length} selected",
              style: GoogleFonts.poppins(
                color: const Color(0xFF4A1818),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_box_outlined),
            onPressed: _selectAll,
            color: const Color(0xFF9E1818),
          ),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _selectedIds.isNotEmpty ? _deleteSelectedMeasurements : null,
              color: _selectedIds.isNotEmpty ? Colors.red : Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    if (_recentActivities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text("No recent activities", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 5),
              Text("Add activities above to see history", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
    child: Column(
  children: _recentActivities.map((activity) {
    final date = activity['date']?.toString() ?? 'No date';
    final type = activity['type']?.toString() ?? '';
    final value = activity['value']?.toString() ?? '';
    final unit = activity['unit']?.toString() ?? '';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF9E1818).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          _measurementIcons[type] ?? Icons.straighten,
          color: const Color(0xFF9E1818),
          size: 20,
        ),
      ),
      title: Text(
        type,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(date),
      trailing: Text(
        "$value $unit",
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF9E1818),
        ),
      ),
    );
  }).toList(),
),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DashboardHeader(title: "Progress Tracking"),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tab Bar
                _buildTabBar(),
                const SizedBox(height: 20),

                // Measurement Type Selector
                _buildMeasurementSelector(),
                const SizedBox(height: 20),

                // Graph with refresh indicator
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      _buildChart(),
                      if (_lastRefreshTime != null)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  "Updated: ${_lastRefreshTime!.hour.toString().padLeft(2, '0')}:${_lastRefreshTime!.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Log New Measurements/Activities
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTab == 0 ? "Log New Measurements" : "Log Daily Activities",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4A1818),
                      ),
                    ),
                    Text(
                      _selectedTab == 0 ? "Enter any measurements below" : "Track your daily progress",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Input section based on selected tab
                _selectedTab == 0 ? _buildBodyMeasurementsInput() : _buildDailyActivitiesInput(),
                
                // Single Save Button
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAllMeasurements,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E1818),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _selectedTab == 0 ? "Save All Measurements" : "Save Activities",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 40),

                // History Section
                if (_selectedTab == 0) ...[
                  // Recent Measurements with delete controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Measurement History",
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF4A1818)),
                      ),
                      Row(
                        children: [
                          if (_isLoadingChart)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Color(0xFF9E1818)),
                            onPressed: _isLoadingChart ? null : () {
                              _loadChartData();
                              _loadRecentMeasurements();
                            },
                            tooltip: "Refresh",
                          ),
                          IconButton(
                            icon: Icon(
                              _isSelectionMode ? Icons.cancel : Icons.select_all,
                              color: const Color(0xFF9E1818),
                            ),
                            onPressed: _toggleSelectionMode,
                            tooltip: _isSelectionMode ? "Cancel Selection" : "Select Items",
                          ),
                          _buildDeleteMenu(),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Filter Controls
                  _buildFilterControls(),
                  
                  // Selection Controls
                  _buildSelectionControls(),
                  
                  // Display recent measurements from local list
                  if (_recentMeasurements.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 40, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("No measurements logged yet", style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 5),
                            Text("Add measurements above to see history", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: _getFilteredMeasurements().map((measurement) {
                          final date = measurement['date']?.toString() ?? 'No date';
                          final type = measurement['type']?.toString() ?? '';
                          final value = measurement['value']?.toString() ?? '';
                          final unit = measurement['unit']?.toString() ?? '';
                          final docId = measurement['id'] as String;
                          final isSelected = _selectedIds.contains(docId);
                          
                          return ListTile(
                            leading: _isSelectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      _toggleSelection(docId);
                                    },
                                    activeColor: const Color(0xFF9E1818),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9E1818).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _measurementIcons[type] ?? Icons.straighten,
                                      color: const Color(0xFF9E1818),
                                      size: 20,
                                    ),
                                  ),
                            title: Text(
                              type,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(date),
                            trailing: Text(
                              "$value $unit",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF9E1818),
                              ),
                            ),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(docId);
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                _isSelectionMode = true;
                                _toggleSelection(docId);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                ] else ...[
                  // Recent Activities for daily activities tab
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recent Activities",
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF4A1818)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF9E1818)),
                        onPressed: _loadRecentActivities,
                        tooltip: "Refresh",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  _buildRecentActivities(),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}