import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';


import 'dashboard.dart';


// ---------------------------------------------------------------------------
// WORKOUT PAGE - MAIN ENTRY
// ---------------------------------------------------------------------------
class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorkoutManagementSection();
  }
}

// ---------------------------------------------------------------------------
// WORKOUT MANAGEMENT SECTION
// ---------------------------------------------------------------------------
class WorkoutManagementSection extends StatefulWidget {
  const WorkoutManagementSection({super.key});

  @override
  State<WorkoutManagementSection> createState() => _WorkoutManagementSectionState();
}

class _WorkoutManagementSectionState extends State<WorkoutManagementSection> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  
  List<WorkoutPlan> _workoutPlans = [];
  List<WorkoutSession> _workoutHistory = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Today's Workout, 1: Workout Plans, 2: History
  WorkoutPlan? _activeWorkout;
  bool _isWorkoutActive = false;
  Duration _workoutDuration = Duration.zero;
  DateTime? _workoutStartTime;
  
  // Timer for active workout
  late Timer _workoutTimer;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
    _checkActiveWorkout();
  }

  @override
  void dispose() {
    _workoutTimer.cancel();
    super.dispose();
  }

  Future<void> _loadWorkoutData() async {
    if (user == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Load workout plans
      final plansSnapshot = await firestore
          .collection('workout_plans')
          .where('userId', isEqualTo: user!.uid)
          .get();

      _workoutPlans = plansSnapshot.docs.map((doc) {
        final data = doc.data();
        return WorkoutPlan.fromMap(data, doc.id);
      }).toList();

      // Load workout history
      final historySnapshot = await firestore
          .collection('workout_sessions')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      _workoutHistory = historySnapshot.docs.map((doc) {
        final data = doc.data();
        return WorkoutSession.fromMap(data);
      }).toList();

      // Set today's workout if not set
      if (_workoutPlans.isNotEmpty && _activeWorkout == null) {
        _activeWorkout = _workoutPlans.firstWhere(
          (plan) => plan.isActive,
          orElse: () => _workoutPlans.first,
        );
      }

    } catch (e) {
      print("Error loading workout data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkActiveWorkout() async {
    if (user == null) return;
    
    final activeSession = await firestore
        .collection('workout_sessions')
        .where('userId', isEqualTo: user!.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (activeSession.docs.isNotEmpty) {
      final data = activeSession.docs.first.data();
      final startTime = (data['startTime'] as Timestamp).toDate();
      setState(() {
        _isWorkoutActive = true;
        _workoutStartTime = startTime;
        _workoutDuration = DateTime.now().difference(startTime);
      });
      
      // Start timer
      _startWorkoutTimer();
    }
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_workoutStartTime != null) {
        setState(() {
          _workoutDuration = DateTime.now().difference(_workoutStartTime!);
        });
      }
    });
  }

  Future<void> _startWorkout() async {
    if (user == null || _activeWorkout == null) return;

    setState(() {
      _isWorkoutActive = true;
      _workoutStartTime = DateTime.now();
      _workoutDuration = Duration.zero;
    });

    _startWorkoutTimer();

    // Create workout session in Firestore
    await firestore.collection('workout_sessions').add({
      'userId': user!.uid,
      'workoutPlanId': _activeWorkout!.id,
      'workoutPlanName': _activeWorkout!.name,
      'startTime': Timestamp.now(),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'isActive': true,
      'exercises': _activeWorkout!.exercises.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> _completeWorkout() async {
    if (user == null) return;

    setState(() {
      _isWorkoutActive = false;
    });

    _workoutTimer.cancel();

    // Update active session
    final activeSession = await firestore
        .collection('workout_sessions')
        .where('userId', isEqualTo: user!.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (activeSession.docs.isNotEmpty) {
      final sessionDoc = activeSession.docs.first;
      final durationInSeconds = _workoutDuration.inSeconds;
      
      await sessionDoc.reference.update({
        'endTime': Timestamp.now(),
        'duration': durationInSeconds,
        'isActive': false,
        'completed': true,
        'caloriesBurned': _calculateCaloriesBurned(durationInSeconds),
      });
    }

    // Reload data
    await _loadWorkoutData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Workout completed! Duration: ${_formatDuration(_workoutDuration)}"),
        backgroundColor: Colors.green,
      ),
    );
  }

  int _calculateCaloriesBurned(int durationInSeconds) {
    // Simple calculation: ~5 calories per minute for moderate exercise
    return (durationInSeconds ~/ 60) * 5;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _createNewWorkoutPlan() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create New Workout Plan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Workout Plan Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: "Description (Optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && user != null) {
                await firestore.collection('workout_plans').add({
                  'userId': user!.uid,
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'isActive': true,
                  'exercises': [],
                  'createdAt': Timestamp.now(),
                  'updatedAt': Timestamp.now(),
                });
                
                await _loadWorkoutData();
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _addExerciseToPlan(String planId) async {
    final nameController = TextEditingController();
    final setsController = TextEditingController(text: "3");
    final repsController = TextEditingController(text: "10");
    final durationController = TextEditingController(text: "60");

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Exercise"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Exercise Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Sets",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: repsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Reps",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Duration (seconds)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final exercise = {
                  'name': nameController.text,
                  'sets': int.tryParse(setsController.text) ?? 3,
                  'reps': int.tryParse(repsController.text) ?? 10,
                  'duration': int.tryParse(durationController.text) ?? 60,
                  'completed': false,
                };

                await firestore.collection('workout_plans').doc(planId).update({
                  'exercises': FieldValue.arrayUnion([exercise]),
                  'updatedAt': Timestamp.now(),
                });

                await _loadWorkoutData();
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3F0),
      body: Column(
        children: [
          const DashboardHeader(title: "Let's spice things up!"),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Tab Selection
                      Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _buildTabOption("Today", 0),
                            _buildTabOption("Plans", 1),
                            _buildTabOption("History", 2),
                          ],
                        ),
                      ),
                      
                      // Tab Content
                      Expanded(
                        child: _selectedTab == 0
                            ? _buildTodayWorkout()
                            : _selectedTab == 1
                                ? _buildWorkoutPlans()
                                : _buildWorkoutHistory(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption(String text, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF9E1818) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayWorkout() {
    if (_activeWorkout == null && _workoutPlans.isNotEmpty) {
      _activeWorkout = _workoutPlans.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Workout Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeWorkout?.name ?? "No Active Workout",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_activeWorkout != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBF1E1E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_activeWorkout!.exercises.length} exercises",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_activeWorkout?.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    _activeWorkout!.description!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                
                // Workout Timer/Progress
                if (_isWorkoutActive) ...[
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _formatDuration(_workoutDuration),
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF9E1818),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Workout in Progress",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ] else if (_activeWorkout != null) ...[
                  Center(
                    child: CircularPercentIndicator(
                      radius: 95,
                      lineWidth: 16,
                      percent: 0.0,
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "READY",
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF9E1818),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Tap to start",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      progressColor: const Color(0xFF7A0D0D),
                      backgroundColor: Colors.grey.shade200,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                
                // Start/Complete Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _activeWorkout == null
                        ? null
                        : _isWorkoutActive
                            ? _completeWorkout
                            : _startWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isWorkoutActive ? Colors.green : const Color(0xFF9E1818),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isWorkoutActive ? "COMPLETE WORKOUT" : "START WORKOUT",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Exercises List
          if (_activeWorkout != null && _activeWorkout!.exercises.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              "Exercises",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A1818),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Exercise",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Sets",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Reps",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Time",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ..._activeWorkout!.exercises.map((exercise) => _buildExerciseRow(exercise)),
                ],
              ),
            ),
          ],
          
          // Create New Workout Button
          if (_activeWorkout == null) ...[
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 60,
                      color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No Workout Plan Set",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A1818),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Create your first workout plan to get started",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _createNewWorkoutPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E1818),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Create Workout Plan",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            )
          ],
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(Exercise exercise) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              exercise.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              "${exercise.sets}",
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              "${exercise.reps}",
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              "${exercise.duration}s",
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutPlans() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Workout Plans",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A1818),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createNewWorkoutPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9E1818),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text("New Plan"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_workoutPlans.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 60,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "No Workout Plans Yet",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._workoutPlans.map((plan) => _buildWorkoutPlanCard(plan)),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildWorkoutPlanCard(WorkoutPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (plan.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Active",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(
                      _activeWorkout?.id == plan.id ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _activeWorkout?.id == plan.id ? const Color(0xFF9E1818) : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _activeWorkout = plan;
                      });
                      // Update active status in Firestore
                      for (final p in _workoutPlans) {
                        firestore.collection('workout_plans').doc(p.id).update({
                          'isActive': p.id == plan.id,
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          
          if (plan.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              plan.description!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.list, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                "${plan.exercises.length} exercises",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 20, color: Color(0xFF9E1818)),
                onPressed: () => _addExerciseToPlan(plan.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () async {
                  await firestore.collection('workout_plans').doc(plan.id).delete();
                  await _loadWorkoutData();
                },
              ),
            ],
          ),
          
          if (plan.exercises.isNotEmpty) ...[
            const SizedBox(height: 15),
            ...plan.exercises.take(3).map((exercise) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E1818),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${exercise.name} - ${exercise.sets} sets x ${exercise.reps} reps",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            if (plan.exercises.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "+${plan.exercises.length - 3} more exercises",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutHistory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Workout History",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 20),
          
          if (_workoutHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 60,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "No Workout History",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      "Complete your first workout to see history",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._workoutHistory.map((session) => _buildHistoryCard(session)),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(WorkoutSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                session.workoutPlanName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9E1818).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  session.date,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF9E1818),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                _formatDuration(Duration(seconds: session.duration)),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 20),
              Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                "${session.caloriesBurned} cal",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 20),
              Icon(Icons.list, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                "${session.exercises.length} exercises",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          if (session.exercises.isNotEmpty) ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: session.exercises.take(4).map((exercise) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  exercise.name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              )).toList(),
            ),
            if (session.exercises.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "+${session.exercises.length - 4} more exercises",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------
class WorkoutPlan {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final List<Exercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutPlan({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.exercises,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutPlan.fromMap(Map<String, dynamic> data, String id) {
    final exercises = (data['exercises'] as List<dynamic>? ?? []).map((e) {
      return Exercise.fromMap(e);
    }).toList();

    return WorkoutPlan(
      id: id,
      name: data['name'] ?? 'Unnamed Workout',
      description: data['description'],
      isActive: data['isActive'] ?? false,
      exercises: exercises,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Exercise {
  final String name;
  final int sets;
  final int reps;
  final int duration; // in seconds
  final bool completed;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.duration,
    this.completed = false,
  });

  factory Exercise.fromMap(Map<String, dynamic> data) {
    return Exercise(
      name: data['name'] ?? '',
      sets: data['sets'] ?? 0,
      reps: data['reps'] ?? 0,
      duration: data['duration'] ?? 0,
      completed: data['completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'duration': duration,
      'completed': completed,
    };
  }
}

class WorkoutSession {
  final String workoutPlanId;
  final String workoutPlanName;
  final String date;
  final int duration; // in seconds
  final int caloriesBurned;
  final List<Exercise> exercises;

  WorkoutSession({
    required this.workoutPlanId,
    required this.workoutPlanName,
    required this.date,
    required this.duration,
    required this.caloriesBurned,
    required this.exercises,
  });

  factory WorkoutSession.fromMap(Map<String, dynamic> data) {
    final exercises = (data['exercises'] as List<dynamic>? ?? []).map((e) {
      return Exercise.fromMap(e);
    }).toList();

    return WorkoutSession(
      workoutPlanId: data['workoutPlanId'] ?? '',
      workoutPlanName: data['workoutPlanName'] ?? 'Unknown Workout',
      date: data['date'] ?? '',
      duration: data['duration'] ?? 0,
      caloriesBurned: data['caloriesBurned'] ?? 0,
      exercises: exercises,
    );
  }
}