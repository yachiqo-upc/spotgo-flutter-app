import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/spotgo_logo.dart';

void main() {
  runApp(const SpotGoAdminApp());
}

class SpotGoAdminApp extends StatelessWidget {
  const SpotGoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotGo Parking Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const Scaffold(body: Center(child: SpotGoLogo(fontSize: 36))),
    );
  }
}
