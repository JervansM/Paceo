import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


// import your screens
import 'register.dart';
import 'welcome.dart';
import 'signup.dart';
import 'dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully!");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }

  runApp(const PaceoApp());
}

class PaceoApp extends StatelessWidget {
  const PaceoApp({super.key});  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paceo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins', useMaterial3: true),

      initialRoute: RegisterScreen.routeName,

      routes: {
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        WelcomeScreen.routeName: (_) => const WelcomeScreen(),
        SignupScreen.routeName: (_) => const SignupScreen(),
        DashboardScreen.routeName: (_) => const DashboardScreen(),
      },
    );
  }
}
