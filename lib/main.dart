import 'package:flutter/material.dart';

import 'presentation/home/home.dart';

void main() {
  runApp(const SesApp());
}

/// Root widget of the S.E.S. (Smile Enjoy Story) app.
class SesApp extends StatelessWidget {
  const SesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S.E.S.',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeShellPage(),
    );
  }
}
