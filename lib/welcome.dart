import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class WelcomeScreen extends StatefulWidget {
  static const String routeName = '/welcome';
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> login() async {
  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    showMessage("Please enter both email and password.");
    return;
  }

  setState(() => isLoading = true);

  try {
    // STEP 1 — Sign in using FirebaseAuth
    UserCredential userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    // STEP 2 — Validate the user exists in Firestore "users" collection
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (!doc.exists) {
      showMessage("User record not found. Invalid credentials.");
      FirebaseAuth.instance.signOut(); // force logout
      setState(() => isLoading = false);
      return;
    }

    // SUCCESS — Firestore user exists
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/dashboard',
      (route) => false,
    );
  } on FirebaseAuthException catch (e) {
    String msg = "Login failed";

    if (e.code == 'user-not-found') msg = "No account exists with this email.";
    if (e.code == 'wrong-password') msg = "Incorrect password.";
    if (e.code == 'invalid-email') msg = "Invalid email format.";
    if (e.code == 'invalid-credential') msg = "Incorrect email or password.";

    showMessage(msg);
  } catch (e) {
    showMessage("Unexpected error occurred.");
  }

  setState(() => isLoading = false);
}


  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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

          // Welcome Back
          const Positioned(
            top: 304,
            left: 116,
            right: 40,
            child: Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.w700,
                color: Color(0xFFAA1308),
              ),
            ),
          ),

          // Email
          Positioned(
            top: 395,
            left: 40,
            right: 40,
            child: TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
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
            top: 480,
            left: 40,
            right: 40,
            child: TextField(
              controller: passwordController,
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

          // Forgot Password
          Positioned(
            top: 550,
            right: 40,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Forgot password?'),
            ),
          ),

          // LOGIN BUTTON (Now with Validation + FirebaseAuth)
          Positioned(
            top: 715,
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
                  onPressed: isLoading ? null : login,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'LOGIN',
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

          // Sign Up link
Positioned(
  top: 870,
  left: 40,
  right: 40,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text("Don't have an Account? "),
      GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/signup');
        },
        child: const Text(
          'Sign Up',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
),
        ],
      ),
    );
  }
}
