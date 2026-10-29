import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';
import 'screens.dart';

void main() {
  // Splash-freeze rule: runApp() se pehle koi storage await NAHI.
  // Data lazily load hota hai (AppStore.init pehle frame ke baad).
  runApp(const KhataBookApp());
}

class KhataBookApp extends StatefulWidget {
  const KhataBookApp({super.key});

  @override
  State<KhataBookApp> createState() => _KhataBookAppState();
}

class _KhataBookAppState extends State<KhataBookApp> {
  @override
  void initState() {
    super.initState();
    // Pehla frame render honay ke baad data load karo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStore.instance.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khata Book',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const MainShell(),
    );
  }
}
