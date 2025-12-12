import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:paceo/meals.dart';
import 'package:paceo/workout.dart' ;
import 'package:paceo/progress.dart' ;
import 'package:paceo/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paceo Fitness',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF3F0),
        primaryColor: const Color(0xFF9E1818),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E1818),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String userName = "User";
  String userEmail = "";
  bool isLoadingUser = true;
  
  // Dashboard stats
  double dailyCalories = 0;
  double dailyProtein = 0;
  double dailyCarbs = 0;
  double dailyFat = 0;
  double waterIntake = 0;
  int steps = 0;
  double sleepHours = 0;
  double weight = 70.0;
  double bodyFat = 20.0;
  int workoutMinutes = 0;
  
  // Goals
  double calorieGoal = 2200;
  double proteinGoal = 120;
  double waterGoal = 2.5;
  int stepsGoal = 10000;
  double sleepGoal = 8.0;
  
  // Recent activities
  List<Map<String, dynamic>> recentActivities = [];
  
  // Weekly data for charts
  List<double> weeklyWeightData = [];
  List<double> weeklyCaloriesData = [];
  List<String> weeklyLabels = [];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        userEmail = user.email ?? "";

        final doc = await firestore
            .collection("users")
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          userName = data["name"] ?? "User";
          weight = (data["weight"] ?? 70.0).toDouble();
          bodyFat = (data["bodyFat"] ?? 20.0).toDouble();
          calorieGoal = (data["calorieGoal"] ?? 2200).toDouble();
          proteinGoal = (data["proteinGoal"] ?? 120).toDouble();
          waterGoal = (data["waterGoal"] ?? 2.5).toDouble();
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      setState(() {
        isLoadingUser = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    final user = auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // Load today's meals
      final mealsSnapshot = await firestore
          .collection('meals')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .get();

      dailyCalories = 0;
      dailyProtein = 0;
      dailyCarbs = 0;
      dailyFat = 0;
      
      for (final doc in mealsSnapshot.docs) {
        final foods = (doc.data()['foods'] as List<dynamic>?) ?? [];
        for (final food in foods) {
          dailyCalories += (food['calories'] ?? 0).toDouble();
          dailyProtein += (food['protein'] ?? 0).toDouble();
          dailyCarbs += (food['carbs'] ?? 0).toDouble();
          dailyFat += (food['fat'] ?? 0).toDouble();
        }
      }

      // Load today's workout
      final workoutSnapshot = await firestore
          .collection('workout_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .get();

      workoutMinutes = 0;
      for (final doc in workoutSnapshot.docs) {
        final data = doc.data();
        workoutMinutes += ((data['durationMinutes'] ?? 0) as num).toInt();

      }

      // Load recent activities
      recentActivities = [];
      
      // Add meal activities
      for (final doc in mealsSnapshot.docs) {
        final data = doc.data();
        final foods = (data['foods'] as List<dynamic>?) ?? [];
        if (foods.isNotEmpty) {
          final time = data['createdAt'] != null 
              ? DateFormat('HH:mm').format(DateTime.parse(data['createdAt']))
              : 'Just now';
          
          recentActivities.add({
            'type': 'meal',
            'time': time,
            'title': 'Meal logged',
            'subtitle': foods.map((f) => f['name']).join(', '),
            'icon': Icons.restaurant,
            'color': Colors.orange,
            'timestamp': data['createdAt'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      // Add workout activities
      for (final doc in workoutSnapshot.docs) {
        final data = doc.data();
        if (data['completed'] == true) {
          final time = data['createdAt'] != null 
              ? DateFormat('HH:mm').format(DateTime.parse(data['createdAt']))
              : 'Today';
          
          recentActivities.add({
            'type': 'workout',
            'time': time,
            'title': 'Workout completed',
            'subtitle': data['workoutPlanName'] ?? 'Workout',
            'icon': Icons.fitness_center,
            'color': Colors.red,
            'timestamp': data['createdAt'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      // Add measurement activities (from trackprogress)
      final measurementsSnapshot = await firestore
          .collection('trackprogress')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .get();

      for (final doc in measurementsSnapshot.docs) {
        final data = doc.data();
        final time = data['createdAt'] != null 
              ? DateFormat('HH:mm').format(DateTime.parse(data['createdAt']))
              : 'Just now';
        
        recentActivities.add({
          'type': 'measurement',
          'time': time,
          'title': '${data['type']} updated',
          'subtitle': '${data['value']} ${data['unit']}',
          'icon': Icons.straighten,
          'color': Colors.blue,
          'timestamp': data['createdAt'] ?? DateTime.now().toIso8601String(),
        });
      }

      // Sort activities by timestamp
      recentActivities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      // Load weekly data for charts
      await _loadWeeklyData();

      // Load water intake
      final waterDoc = await firestore
          .collection('water_intake')
          .doc('${user.uid}_$today')
          .get();
      
      waterIntake = waterDoc.exists ? (waterDoc.data()?['amount'] ?? 0).toDouble() : 0;

      // Load steps (simulated for now - integrate with health APIs)
      final stepsDoc = await firestore
          .collection('daily_stats')
          .doc('${user.uid}_$today')
          .get();
      
      steps = stepsDoc.exists ? (stepsDoc.data()?['steps'] ?? 5342).toInt() : 5342;

      // Load sleep (simulated for now)
      final sleepDoc = await firestore
          .collection('sleep_tracking')
          .doc('${user.uid}_$today')
          .get();
      
      sleepHours = sleepDoc.exists ? (sleepDoc.data()?['hours'] ?? 6.5).toDouble() : 6.5;

      // Load latest weight
      final weightSnapshot = await firestore
          .collection('trackprogress')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'Weight')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (weightSnapshot.docs.isNotEmpty) {
        weight = (weightSnapshot.docs.first.data()['value'] ?? weight).toDouble();
      }

      // Load latest body fat
      final bodyFatSnapshot = await firestore
          .collection('trackprogress')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'Body Fat %')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (bodyFatSnapshot.docs.isNotEmpty) {
        bodyFat = (bodyFatSnapshot.docs.first.data()['value'] ?? bodyFat).toDouble();
      }

    } catch (e) {
      print("Error loading dashboard data: $e");
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadWeeklyData() async {
    final user = auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    weeklyWeightData = List.filled(7, weight);
    weeklyCaloriesData = List.filled(7, 0.0);
    weeklyLabels = [];

    // Generate labels for the past 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      weeklyLabels.add(DateFormat('E').format(date)); // Mon, Tue, etc.
    }

    try {
      // Load weight data for the past week
      final weekAgo = now.subtract(const Duration(days: 7));
      final weightSnapshot = await firestore
          .collection('trackprogress')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'Weight')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('timestamp')
          .get();

      // Group weight data by day
      final weightByDay = <String, List<double>>{};
      for (final doc in weightSnapshot.docs) {
        final data = doc.data();
        final dateStr = data['date']?.toString() ?? '';
        if (dateStr.isNotEmpty) {
          weightByDay.putIfAbsent(dateStr, () => []).add(data['value'].toDouble());
        }
      }

      // Calculate average weight for each day and fill the array
      for (int i = 0; i < 7; i++) {
        final date = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 6 - i)));
        final weights = weightByDay[date];
        if (weights != null && weights.isNotEmpty) {
          weeklyWeightData[i] = weights.reduce((a, b) => a + b) / weights.length;
        }
      }

      // Load calorie data for the past week
      for (int i = 0; i < 7; i++) {
        final date = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 6 - i)));
        final mealsSnapshot = await firestore
            .collection('meals')
            .where('userId', isEqualTo: user.uid)
            .where('date', isEqualTo: date)
            .get();
        
        double dayCalories = 0;
        for (final doc in mealsSnapshot.docs) {
          final foods = (doc.data()['foods'] as List<dynamic>?) ?? [];
          for (final food in foods) {
            dayCalories += (food['calories'] ?? 0).toDouble();
          }
        }
        weeklyCaloriesData[i] = dayCalories;
      }

    } catch (e) {
      print("Error loading weekly data: $e");
    }
  }

  Widget _buildWelcomeCard() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    
    if (hour < 12) {
      greeting = "Good Morning";
    } else if (hour < 18) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9E1818), Color(0xFF7A0D0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E1818).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$greeting, $userName!",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Keep up the great work!",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${weight.toStringAsFixed(1)} kg",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${dailyCalories.toStringAsFixed(0)}/$calorieGoal kcal",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                isLoadingUser = true;
              });
              _loadDashboardData().then((_) {
                setState(() {
                  isLoadingUser = false;
                });
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                "Health Metrics",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A1818),
                ),
              ),
              Text(
                "Today",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: [
              _buildMetricCard(
                title: "Calories",
                value: "${dailyCalories.toStringAsFixed(0)} kcal",
                progress: dailyCalories / calorieGoal,
                icon: Icons.local_fire_department,
                color: Colors.orange,
                goal: "/ $calorieGoal kcal",
              ),
              _buildMetricCard(
                title: "Protein",
                value: "${dailyProtein.toStringAsFixed(1)}g",
                progress: dailyProtein / proteinGoal,
                icon: Icons.fitness_center,
                color: Colors.blue,
                goal: "/ $proteinGoal g",
              ),
              _buildMetricCard(
                title: "Water",
                value: "${waterIntake.toStringAsFixed(1)}L",
                progress: waterIntake / waterGoal,
                icon: Icons.water_drop,
                color: Colors.blue.shade300,
                goal: "/ $waterGoal L",
              ),
              _buildMetricCard(
                title: "Steps",
                value: "$steps",
                progress: steps / stepsGoal,
                icon: Icons.directions_walk,
                color: Colors.green,
                goal: "/ $stepsGoal",
              ),
              _buildMetricCard(
                title: "Sleep",
                value: "${sleepHours.toStringAsFixed(1)}h",
                progress: sleepHours / sleepGoal,
                icon: Icons.bedtime,
                color: Colors.purple,
                goal: "/ ${sleepGoal}h",
              ),
              _buildMetricCard(
                title: "Workout",
                value: "$workoutMinutes min",
                progress: workoutMinutes / 60, // Assuming 60 min goal
                icon: Icons.fitness_center,
                color: Colors.red,
                goal: "Today",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required double progress,
    required IconData icon,
    required Color color,
    required String goal,
    bool showProgress = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A1818),
            ),
          ),
          Text(
            goal,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.grey.shade200,
              color: progress > 1 ? Colors.red : color,
              borderRadius: BorderRadius.circular(10),
              minHeight: 6,
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "${(progress * 100).toStringAsFixed(0)}%",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: progress > 1 ? Colors.red : color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nutrition Breakdown",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroCard("Protein", "${dailyProtein}g", Colors.blue, Icons.fitness_center),
              _buildMacroCard("Carbs", "${dailyCarbs}g", Colors.green, Icons.grain),
              _buildMacroCard("Fat", "${dailyFat}g", Colors.orange, Icons.oil_barrel),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: dailyCalories / calorieGoal,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF9E1818),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${dailyCalories.toStringAsFixed(0)} kcal",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A1818),
                ),
              ),
              Text(
                "${calorieGoal.toStringAsFixed(0)} kcal goal",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String title, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A1818),
          ),
        ),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                "Weekly Progress",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A1818),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list, color: Colors.grey),
                onSelected: (value) {
                  // Handle filter selection
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'weight', child: Text('Weight Only')),
                  const PopupMenuItem(value: 'calories', child: Text('Calories Only')),
                  const PopupMenuItem(value: 'both', child: Text('Both')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Weight & Calorie Trends",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < weeklyLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              weeklyLabels[index],
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            value.toInt().toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 0,
                maxX: weeklyWeightData.length > 0 ? weeklyWeightData.length - 1 : 6,
                minY: weeklyWeightData.isNotEmpty 
                    ? weeklyWeightData.reduce((a, b) => a < b ? a : b) - 2
                    : 60,
                maxY: weeklyCaloriesData.isNotEmpty 
                    ? (weeklyCaloriesData.reduce((a, b) => a > b ? a : b) / 100).ceilToDouble() * 100 / 10
                    : 250,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(weeklyWeightData.length, (index) {
                      return FlSpot(index.toDouble(), weeklyWeightData[index]);
                    }),
                    isCurved: true,
                    color: const Color(0xFF9E1818),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9E1818).withOpacity(0.3),
                          const Color(0xFF9E1818).withOpacity(0.0),
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
                  ),
                  LineChartBarData(
                    spots: List.generate(weeklyCaloriesData.length, (index) {
                      return FlSpot(index.toDouble(), weeklyCaloriesData[index] / 10);
                    }),
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF9E1818),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Weight (kg)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Calories (x10)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                "Recent Activity",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A1818),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to activity log page
                },
                child: Text(
                  "View All",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9E1818),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (recentActivities.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "No recent activity",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    "Log a meal or complete a workout to see activity here",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...recentActivities.take(5).map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: activity['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activity['icon'], color: activity['color'], size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4A1818),
                  ),
                ),
                Text(
                  activity['subtitle'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            activity['time'],
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      )
    );
  
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: [
              _buildQuickActionButton(
                title: "Log Meal",
                icon: Icons.restaurant,
                color: Colors.orange,
                onTap: () => _navigateToPage(1),
              ),
              _buildQuickActionButton(
                title: "Start Workout",
                icon: Icons.fitness_center,
                color: Colors.red,
                onTap: () => _navigateToPage(2),
              ),
              _buildQuickActionButton(
                title: "Add Water",
                icon: Icons.water_drop,
                color: Colors.blue,
                onTap: _logWaterIntake,
              ),
              _buildQuickActionButton(
                title: "Add Measurement",
                icon: Icons.straighten,
                color: Colors.green,
                onTap: () => _navigateToProgressSectionWithMeasurement(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _logWaterIntake() async {
    final user = auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Water Intake"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Current: ${waterIntake.toStringAsFixed(1)}L / $waterGoal L",
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWaterButton(0.25, "250ml"),
                _buildWaterButton(0.5, "500ml"),
                _buildWaterButton(1.0, "1L"),
              ],
            ),
          ],
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

  Widget _buildWaterButton(double amount, String label) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final user = auth.currentUser;
            if (user == null) return;
            
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final newAmount = waterIntake + amount;
            
            await firestore
                .collection('water_intake')
                .doc('${user.uid}_$today')
                .set({
                  'userId': user.uid,
                  'date': today,
                  'amount': newAmount,
                  'timestamp': Timestamp.now(),
                });
            
            setState(() {
              waterIntake = newAmount;
            });
            
            // Add to recent activities
            recentActivities.insert(0, {
              'type': 'water',
              'time': 'Just now',
              'title': 'Water logged',
              'subtitle': '+${amount}L (${newAmount.toStringAsFixed(1)}L total)',
              'icon': Icons.water_drop,
              'color': Colors.blue,
              'timestamp': DateTime.now().toIso8601String(),
            });
            
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.blue.withOpacity(0.1),
          ),
          child: Icon(
            Icons.water_drop,
            color: Colors.blue,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
      ],
    );
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToProgressSectionWithMeasurement() {
    setState(() {
      _currentIndex = 3;
    });
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Stats",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard("Weight", "${weight.toStringAsFixed(1)} kg", Icons.monitor_weight),
              _buildStatCard("Body Fat", "${bodyFat.toStringAsFixed(1)}%", Icons.pie_chart),
              _buildStatCard("BMI", "${(weight / ((1.75) * (1.75))).toStringAsFixed(1)}", Icons.calculate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1818).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF9E1818), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A1818),
          ),
        ),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      Column(
        children: [
          const DashboardHeader(title: "Dashboard"),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),
                  _buildHealthMetrics(),
                  const SizedBox(height: 20),
                  _buildNutritionBreakdown(),
                  const SizedBox(height: 20),
                  _buildUserStats(),
                  const SizedBox(height: 20),
                  _buildWeeklyChart(),
                  const SizedBox(height: 20),
                  _buildRecentActivity(),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      MealsPage(),
      WorkoutPage(),
      ProgressSection(),
      const ProfilePage(),
    ];

    if (isLoadingUser) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF3F0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF3F0),
      body: screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF9E1818),
          unselectedItemColor: Colors.grey.shade600,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _currentIndex == 0
                    ? BoxDecoration(
                        color: const Color(0xFF9E1818).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  Icons.home_outlined,
                  size: _currentIndex == 0 ? 24 : 22,
                ),
              ),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _currentIndex == 1
                    ? BoxDecoration(
                        color: const Color(0xFF9E1818).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  Icons.restaurant_outlined,
                  size: _currentIndex == 1 ? 24 : 22,
                ),
              ),
              label: "Meals",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _currentIndex == 2
                    ? BoxDecoration(
                        color: const Color(0xFF9E1818).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  Icons.fitness_center_outlined,
                  size: _currentIndex == 2 ? 24 : 22,
                ),
              ),
              label: "Workout",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _currentIndex == 3
                    ? BoxDecoration(
                        color: const Color(0xFF9E1818).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  Icons.analytics_outlined,
                  size: _currentIndex == 3 ? 24 : 22,
                ),
              ),
              label: "Progress",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _currentIndex == 4
                    ? BoxDecoration(
                        color: const Color(0xFF9E1818).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  Icons.person_outlined,
                  size: _currentIndex == 4 ? 24 : 22,
                ),
              ),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  final String title;
  const DashboardHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE60000), Color(0xFFAA1308), Color(0xFF440803)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}