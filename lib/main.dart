import 'package:flutter/material.dart';

import 'ui/browser_page.dart';
import 'ui/theme.dart';

void main() {
  runApp(const SwitchMtpApp());
}

class SwitchMtpApp extends StatelessWidget {
  const SwitchMtpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Switch MTP',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const BrowserPage(),
    );
  }
}
