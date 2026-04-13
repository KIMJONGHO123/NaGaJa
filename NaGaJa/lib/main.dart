import "package:flutter/material.dart";

import "views/home/home_screen.dart";

void main() {
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
