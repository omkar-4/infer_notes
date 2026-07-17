import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'features/notes/note_editor_screen.dart';
import 'core/theme.dart';
import 'features/updater/updater_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Ignore if .env is missing
  }
  
  // Initialize window_manager to control the native OS window title purely from Dart
  await windowManager.ensureInitialized();
  
  const WindowOptions windowOptions = WindowOptions(
    size: Size(600, 400),
    title: 'Infer Notes',
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('Infer Notes');
    await windowManager.setPreventClose(true);
    await windowManager.show();
  });
  
  // Initialize the auto-update engine on startup
  await UpdaterService.initialize();
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Infer Notes',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const NoteEditorScreen(),
        );
      },
    );
  }
}
