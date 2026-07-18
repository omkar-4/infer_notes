import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = DefaultSpellCheckService();
  
  final start = DateTime.now();
  final suggestions = await service.fetchSpellCheckSuggestions(
    const Locale('en', 'US'),
    'helloo world',
  );
  print(suggestions);
  print('Took: ${DateTime.now().difference(start).inMilliseconds}ms');
}
