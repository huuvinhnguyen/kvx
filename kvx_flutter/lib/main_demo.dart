import 'package:flutter/material.dart';
import 'presentation/screens/relay_widgets_demo_screen.dart';

void main() {
  runApp(const RelayWidgetsDemoApp());
}

class RelayWidgetsDemoApp extends StatelessWidget {
  const RelayWidgetsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relay Widgets Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RelayWidgetsDemoScreen(),
    );
  }
}
