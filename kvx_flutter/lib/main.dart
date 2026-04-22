import 'package:flutter/material.dart';
import 'views/screens/device_list_screen.dart';

void main() {
  runApp(const KvxApp());
}

class KvxApp extends StatelessWidget {
  const KvxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KVX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DeviceListScreen(),
    );
  }
}
