import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/accessibility_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttentionSeekerApp());
}

class AttentionSeekerApp extends StatelessWidget {
  const AttentionSeekerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: a11yService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Attention Seeker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getThemeData(
            highContrast: a11yService.isHighContrastMode,
            largeFont: a11yService.isLargeFontMode,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
