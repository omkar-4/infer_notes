import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FeedbackService {
  static String get _webhookUrl => dotenv.isInitialized ? (dotenv.env['DISCORD_WEBHOOK_URL'] ?? '') : '';

  /// Sends feedback text to the configured Discord Webhook.
  static Future<bool> sendFeedback(String message) async {
    if (_webhookUrl.isEmpty) {
      return false; 
    }

    // Discord has a strict 2000 character limit per message.
    final safeMessage = message.length > 1900 ? '${message.substring(0, 1900)}...' : message;

    try {
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'embeds': [
            {
              'title': 'New User Feedback',
              'color': 3066993, // Green
              'description': safeMessage,
            }
          ]
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Sends silent background diagnostic errors to Discord.
  static Future<void> sendDiagnostic(String errorContext, String details) async {
    if (_webhookUrl.isEmpty) {
      print('FeedbackService: DISCORD_WEBHOOK_URL is empty! Did .env load?');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'embeds': [
            {
              'title': 'Diagnostic Alert ($errorContext)',
              'color': 15158332, // Red
              'description': details,
            }
          ]
        }),
      );
      if (response.statusCode >= 400) {
        print('FeedbackService: Discord returned HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('FeedbackService HTTP Exception: $e');
    }
  }
}
