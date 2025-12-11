import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class SignupScreen extends StatefulWidget {
  static const String routeName = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

 Future<void> signUp() async {
  final name = nameController.text.trim();
  final email = emailController.text.trim();
  final password = passwordController.text.trim();
  final confirmPassword = confirmPasswordController.text.trim();

  debugPrint("📝 Attempting signup with: name=$name, email=$email");

  if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
    showMessage("All fields are required.");
    debugPrint("⚠️ Validation failed: some fields are empty");
    return;
  }

  if (password != confirmPassword) {
    showMessage("Passwords do not match.");
    debugPrint("⚠️ Validation failed: passwords do not match");
    return;
  }

  setState(() => isLoading = true);

  try {
    debugPrint("🔐 Creating user with FirebaseAuth");
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    User? user = userCredential.user;
    debugPrint("✅ User created: ${user?.uid}");

    if (user != null) {
      debugPrint("💾 Saving user data to Firestore");
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
      });
      debugPrint("✅ User data saved");

      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } else {
      showMessage("Signup failed. User not created.");
      debugPrint("❌ User object is null after signup");
    }
  } on FirebaseAuthException catch (e) {
    showMessage(e.message ?? "Signup failed");
    debugPrint("❌ FirebaseAuthException: ${e.code} - ${e.message}");
  } catch (e, stack) {
    showMessage("Error saving user data.");
    debugPrint("❌ Unknown error: $e");
    debugPrint(stack.toString());
  }

  setState(() => isLoading = false);
}

void showMessage(String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text)),
  );
}

Future<void> saveUserData(String name, String email) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'uid': uid,
    'name': name,
    'email': email,
    'createdAt': DateTime.now(),
  });
}


  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          SizedBox.expand(
            child: Image.asset('assets/login.png', fit: BoxFit.cover),
          ),

          // Logo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                width: 305,
                height: 305,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Create an account
          const Positioned(
            top: 304,
            left: 80,
            right: 40,
            child: Text(
              'Create an account',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.w700,
                color: Color(0xFFAA1308),
              ),
            ),
          ),

          // Full Name
Positioned(
  top: 395,
  left: 40,
  right: 40,
  child: TextField(
    controller: nameController, // FIXED
    decoration: const InputDecoration(
      labelText: 'Full Name',
      labelStyle: TextStyle(color: Color(0xFFAC150A)),
      border: UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFAC150A)),
      ),
    ),
  ),
),

// Phone or Email
Positioned(
  top: 480,
  left: 40,
  right: 40,
  child: TextField(
    controller: emailController, // FIXED
    decoration: const InputDecoration(
      labelText: 'Email', // recommend: change to email ONLY
      labelStyle: TextStyle(color: Color(0xFFAC150A)),
      border: UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFAC150A)),
      ),
    ),
  ),
),

// Password
Positioned(
  top: 565,
  left: 40,
  right: 40,
  child: TextField(
    controller: passwordController, // FIXED
    obscureText: true,
    decoration: const InputDecoration(
      labelText: 'Password',
      labelStyle: TextStyle(color: Color(0xFFAC150A)),
      border: UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFAC150A)),
      ),
    ),
  ),
),

// Confirm Password
Positioned(
  top: 650,
  left: 40,
  right: 40,
  child: TextField(
    controller: confirmPasswordController, // FIXED
    obscureText: true,
    decoration: const InputDecoration(
      labelText: 'Confirm Password',
      labelStyle: TextStyle(color: Color(0xFFAC150A)),
      border: UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFAC150A)),
      ),
    ),
  ),
),


          // SIGN UP -> after creating an account navigate to welcome or dashboard as you want
          Positioned(
            top: 810,
            left: 110,
            right: 110,
            child: SizedBox(
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE60000),
                      Color(0xFFAA1308),
                      Color(0xFF440803),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextButton(
                  onPressed: isLoading ? null : signUp,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Sign up',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
