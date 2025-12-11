import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _completedToday = false;

  // Static icons for each meal category
  final Map<String, IconData> _categoryIcons = {
    "Breakfast": Icons.breakfast_dining,
    "Lunch": Icons.lunch_dining,
    "Dinner": Icons.dinner_dining,
    "Snack": Icons.local_cafe,
  };

  // Sample meals with calories and protein per 100g
  final Map<String, Map<String, dynamic>> _sampleMeals = {
    "Oatmeal": {
      "caloriesPer100g": 68,
      "proteinPer100g": 2.4,
      "icon": Icons.breakfast_dining,
      "color": Colors.orange.shade100,
    },
    "Grilled Chicken": {
      "caloriesPer100g": 165,
      "proteinPer100g": 31.0,
      "icon": Icons.kebab_dining,
      "color": Colors.brown.shade100,
    },
    "Salad": {
      "caloriesPer100g": 20,
      "proteinPer100g": 1.0,
      "icon": Icons.grass,
      "color": Colors.green.shade100,
    },
    "Banana": {
      "caloriesPer100g": 89,
      "proteinPer100g": 1.1,
      "icon": Icons.emoji_food_beverage,
      "color": Colors.yellow.shade100,
    },
    "Eggs (2 large)": {
      "caloriesPer100g": 155,
      "proteinPer100g": 13.0,
      "icon": Icons.egg,
      "color": Colors.orange.shade100,
    },
    "Brown Rice": {
      "caloriesPer100g": 111,
      "proteinPer100g": 2.6,
      "icon": Icons.rice_bowl,
      "color": Colors.brown.shade100,
    },
    "Salmon": {
      "caloriesPer100g": 208,
      "proteinPer100g": 20.0,
      "icon": Icons.set_meal,
      "color": Colors.pink.shade100,
    },
    "Protein Shake": {
      "caloriesPer100g": 120,
      "proteinPer100g": 25.0,
      "icon": Icons.fitness_center,
      "color": Colors.purple.shade100,
    },
    "Greek Yogurt": {
      "caloriesPer100g": 59,
      "proteinPer100g": 10.0,
      "icon": Icons.icecream,
      "color": Colors.white70,
    },
    "Quinoa": {
      "caloriesPer100g": 120,
      "proteinPer100g": 4.4,
      "icon": Icons.grain,
      "color": Colors.yellow.shade100,
    },
    "Broccoli": {
      "caloriesPer100g": 34,
      "proteinPer100g": 2.8,
      "icon": Icons.eco,
      "color": Colors.green.shade100,
    },
    "Steak": {
      "caloriesPer100g": 271,
      "proteinPer100g": 26.0,
      "icon": Icons.restaurant,
      "color": Colors.red.shade100,
    },
    "Tuna": {
      "caloriesPer100g": 132,
      "proteinPer100g": 29.0,
      "icon": Icons.set_meal,
      "color": Colors.blue.shade100,
    },
    "Tofu": {
      "caloriesPer100g": 76,
      "proteinPer100g": 8.1,
      "icon": Icons.square,
      "color": Colors.white70,
    },
    "Milk": {
      "caloriesPer100g": 42,
      "proteinPer100g": 3.4,
      "icon": Icons.local_drink,
      "color": Colors.white70,
    },
  };

  // Static color for each category
  final Map<String, Color> _categoryColors = {
    "Breakfast": Colors.orange.shade100,
    "Lunch": Colors.green.shade100,
    "Dinner": Colors.blue.shade100,
    "Snack": Colors.purple.shade100,
  };

  final Color _defaultCategoryColor = Colors.grey.shade100;

  Stream<List<Map<String, dynamic>>> _todaysMealsStream() {
    final todayDate = DateTime.now().toIso8601String().substring(0, 10);
    return firestore
        .collection('meals')
        .where('date', isEqualTo: todayDate)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              var data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> _historyStream() {
    return firestore
        .collection('history')
        .orderBy('date', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              var data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> _addMealToCategory(
      String category, String name, double grams, double calories, double protein) async {
    if (_completedToday) return;

    final todayDate = DateTime.now().toIso8601String().substring(0, 10);

    final query = await firestore
        .collection('meals')
        .where('category', isEqualTo: category)
        .where('date', isEqualTo: todayDate)
        .get();

    final foodData = _sampleMeals[name]!;
    final iconCodePoint = foodData['icon'].codePoint;

    if (query.docs.isEmpty) {
      await firestore.collection('meals').add({
        "category": category,
        "date": todayDate,
        "foods": [
          {
            "name": name,
            "grams": grams,
            "calories": calories,
            "protein": protein,
            "iconCodePoint": iconCodePoint,
          }
        ],
      });
    } else {
      final docRef = query.docs.first.reference;
      await docRef.update({
        "foods": FieldValue.arrayUnion([
          {
            "name": name,
            "grams": grams,
            "calories": calories,
            "protein": protein,
            "iconCodePoint": iconCodePoint,
          }
        ])
      });
    }
  }

  void _showAddMealModal(String category) {
    if (_completedToday) return;

    String selectedMeal = _sampleMeals.keys.first;
    double grams = 100;
    double calories = _sampleMeals[selectedMeal]!['caloriesPer100g'] * grams / 100;
    double protein = _sampleMeals[selectedMeal]!['proteinPer100g'] * grams / 100;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Add $category Meal",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4A1818),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Select Food",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: selectedMeal,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _sampleMeals.keys.map((foodName) {
                        final foodData = _sampleMeals[foodName]!;
                        return DropdownMenuItem<String>(
                          value: foodName,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: foodData['color'],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  foodData['icon'],
                                  color: Colors.black87,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foodName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "${foodData['caloriesPer100g']} kcal",
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "• ${foodData['proteinPer100g']}g protein",
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateModal(() {
                            selectedMeal = val;
                            calories = _sampleMeals[selectedMeal]!['caloriesPer100g'] * grams / 100;
                            protein = _sampleMeals[selectedMeal]!['proteinPer100g'] * grams / 100;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Quantity (grams)",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Slider(
                          min: 50,
                          max: 500,
                          divisions: 45,
                          value: grams,
                          label: "${grams.round()}g",
                          activeColor: const Color(0xFF9E1818),
                          inactiveColor: Colors.grey.shade300,
                          onChanged: (val) {
                            setStateModal(() {
                              grams = val;
                              calories = _sampleMeals[selectedMeal]!['caloriesPer100g'] * grams / 100;
                              protein = _sampleMeals[selectedMeal]!['proteinPer100g'] * grams / 100;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("50g", style: GoogleFonts.poppins(color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9E1818).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${grams.round()}g",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF9E1818),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text("500g", style: GoogleFonts.poppins(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9E1818).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF9E1818).withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department,
                                      size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Calories",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${calories.toStringAsFixed(0)} kcal",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9E1818),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.fitness_center, size: 16, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Protein",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${protein.toStringAsFixed(1)} g",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E1818),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await _addMealToCategory(category, selectedMeal, grams, calories, protein);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Add to $category",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  List<Widget> _buildMealCards(List<Map<String, dynamic>> todaysMeals) {
    List<String> categories = ["Breakfast", "Lunch", "Dinner", "Snack"];
    return categories.map((category) {
      final mealDoc = todaysMeals.firstWhere(
        (m) => m['category'] == category,
        orElse: () => {"foods": []},
      );

      final foods = (mealDoc['foods'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      double calories = foods.fold(0, (sum, f) => sum + ((f['calories'] ?? 0) as num));
      double protein = foods.fold(0, (sum, f) => sum + ((f['protein'] ?? 0) as num));

      String subtitle = foods.isEmpty
          ? "No items added"
          : foods.map((f) => "${f['name']} (${f['grams']?.round() ?? 0}g)").join(", ");

      return _mealCard(
        category: category,
        foods: foods,
        subtitle: subtitle,
        calories: calories,
        protein: protein,
        onAdd: _completedToday ? null : () => _showAddMealModal(category),
      );
    }).toList();
  }

  Widget _mealCard({
    required String category,
    required List<Map<String, dynamic>> foods,
    required String subtitle,
    required double calories,
    required double protein,
    VoidCallback? onAdd,
  }) {
    final categoryIcon = _categoryIcons[category] ?? Icons.restaurant;
    final categoryColor = _categoryColors[category] ?? _defaultCategoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(categoryIcon, size: 24, color: const Color(0xFF4A1818)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4A1818),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9E1818),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
          if (foods.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: foods.map((food) {
                final foodName = food['name']?.toString() ?? '';
                final grams = food['grams']?.toDouble() ?? 0;
                final foodCalories = food['calories']?.toDouble() ?? 0;
                final foodProtein = food['protein']?.toDouble() ?? 0;
                final iconCodePoint = food['iconCodePoint'] as int?;
                final icon = iconCodePoint != null
                    ? IconData(iconCodePoint, fontFamily: 'MaterialIcons')
                    : Icons.restaurant;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: const Color(0xFF9E1818)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            foodName,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                "${foodCalories.toStringAsFixed(0)} cal",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${foodProtein.toStringAsFixed(1)}g prot",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          "${calories.toStringAsFixed(0)} cal",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fitness_center, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          "${protein.toStringAsFixed(1)}g prot",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (calories > 0)
                Text(
                  "${foods.length} ${foods.length == 1 ? 'item' : 'items'}",
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

  Widget _buildNutritionCard(double totalCalories, double totalProtein) {
    const double calorieGoal = 2220;
    const double proteinGoal = 120; // Typical protein goal for active individuals
    final double caloriePercentage = (totalCalories / calorieGoal).clamp(0, 1);
    final double proteinPercentage = (totalProtein / proteinGoal).clamp(0, 1);

    Color calorieColor = const Color(0xFF9E1818);
    Color proteinColor = Colors.blue.shade800;

    if (caloriePercentage > 0.9) {
      calorieColor = Colors.red;
    } else if (caloriePercentage > 0.7) {
      calorieColor = Colors.orange;
    }

    if (proteinPercentage > 0.9) {
      proteinColor = Colors.green;
    } else if (proteinPercentage > 0.7) {
      proteinColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Nutrition",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A1818),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircularPercentIndicator(
                      radius: 50,
                      lineWidth: 10,
                      percent: caloriePercentage,
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${totalCalories.toInt()}",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: calorieColor,
                            ),
                          ),
                          Text(
                            "kcal",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      progressColor: calorieColor,
                      backgroundColor: Colors.grey.shade200,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Calories",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "${calorieGoal.toInt()} goal",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    CircularPercentIndicator(
                      radius: 50,
                      lineWidth: 10,
                      percent: proteinPercentage,
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${totalProtein.toInt()}",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: proteinColor,
                            ),
                          ),
                          Text(
                            "g",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      progressColor: proteinColor,
                      backgroundColor: Colors.grey.shade200,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Protein",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "${proteinGoal.toInt()}g goal",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      "Carbs",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "${(totalCalories * 0.5 / 4).toStringAsFixed(0)}g", // 50% of calories from carbs
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "Fat",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "${(totalCalories * 0.3 / 9).toStringAsFixed(0)}g", // 30% of calories from fat
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "Fiber",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "${(totalCalories / 100).toStringAsFixed(0)}g", // Rough estimate
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeToday(List<Map<String, dynamic>> todaysMeals) async {
    final todayDate = DateTime.now().toIso8601String().substring(0, 10);

    double totalCalories = todaysMeals.fold(0, (prev, m) {
      final foods = (m['foods'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      return prev + foods.fold(0, (sum, f) => sum + ((f['calories'] ?? 0) as num));
    });

    double totalProtein = todaysMeals.fold(0, (prev, m) {
      final foods = (m['foods'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      return prev + foods.fold(0, (sum, f) => sum + ((f['protein'] ?? 0) as num));
    });

    await firestore.collection('history').add({
      "date": todayDate,
      "totalCalories": totalCalories,
      "totalProtein": totalProtein,
      "meals": todaysMeals,
      "timestamp": FieldValue.serverTimestamp(),
    });

    final snapshot = await firestore.collection('meals').where('date', isEqualTo: todayDate).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      _completedToday = true;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("✅ Day Completed"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your day has been completed and saved to history.",
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Calories",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${totalCalories.toStringAsFixed(0)} kcal",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.fitness_center, color: Colors.blue),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Protein",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${totalProtein.toStringAsFixed(1)} g",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _historyStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "Error loading history",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.history, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text(
                  "No history yet",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  "Complete your first day to see history here",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "History",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A1818),
              ),
            ),
            const SizedBox(height: 10),
            ...history.map((entry) {
              final date = entry['date']?.toString() ?? '';
              final totalCalories = (entry['totalCalories'] ?? 0).toDouble();
              final totalProtein = (entry['totalProtein'] ?? 0).toDouble();
              final meals = (entry['meals'] as List<dynamic>?) ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                      color: Colors.black.withOpacity(0.05),
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
                          date,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_fire_department,
                                      size: 12, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${totalCalories.toStringAsFixed(0)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.fitness_center, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${totalProtein.toStringAsFixed(0)}g",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: meals.map((meal) {
                        final category = meal['category']?.toString() ?? '';
                        final foods = (meal['foods'] as List<dynamic>?) ?? [];
                        final categoryIcon = _categoryIcons[category] ?? Icons.restaurant;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon, size: 16, color: const Color(0xFF9E1818)),
                              const SizedBox(width: 6),
                              Text(
                                category,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "(${foods.length} items)",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3F0),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
            width: double.infinity,
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
                  "Meals",
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
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _todaysMealsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todaysMeals = snapshot.data ?? [];
                double totalCalories = todaysMeals.fold(0, (prev, m) {
                  final foods = (m['foods'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                  return prev + foods.fold(0, (sum, f) => sum + ((f['calories'] ?? 0) as num));
                });

                double totalProtein = todaysMeals.fold(0, (prev, m) {
                  final foods = (m['foods'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                  return prev + foods.fold(0, (sum, f) => sum + ((f['protein'] ?? 0) as num));
                });

                if (todaysMeals.isNotEmpty && _completedToday == false) {
                  final hasAllCategories = ["Breakfast", "Lunch", "Dinner", "Snack"]
                      .every((cat) => todaysMeals.any((m) => m['category'] == cat));
                  if (hasAllCategories) {
                    // Could set _completedToday = true here if you want auto-completion
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNutritionCard(totalCalories, totalProtein),
                      const SizedBox(height: 20),
                      Text(
                        "Today's Log",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4A1818),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ..._buildMealCards(todaysMeals),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _completedToday
                                ? Colors.grey
                                : Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _completedToday || todaysMeals.isEmpty
                              ? null
                              : () => _completeToday(todaysMeals),
                          child: Text(
                            _completedToday ? "✓ Day Completed" : "Complete Today",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_completedToday)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Today is completed. Start fresh tomorrow!",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildHistoryTable(),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}