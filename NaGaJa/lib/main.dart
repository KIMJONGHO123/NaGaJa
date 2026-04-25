import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";

import "firebase_options.dart";
import "views/home/home_screen.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NagajaApp());
}

class NagajaApp extends StatelessWidget {
  const NagajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Nagaja",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
