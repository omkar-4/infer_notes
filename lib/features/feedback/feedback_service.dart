import 'dart:convert';
import 'package:http/http.dart' as http;

class FeedbackService {
  /// Note: Replace this with your actual Discord Webhook URL.
  /// (Instructions provided in chat on how to generate this URL)
  static const String _webhookUrl = 'YOUR_DISCORD_WEBHOOK_URL_HERE';

  /// Sends feedback text to the configured Discord Webhook.
  static Future<bool> sendFeedback(String message) async {
    if (_webhookUrl == 'YOUR_DISCORD_WEBHOOK_URL_HERE') {
      // Fail safely if the webhook isn't configured yet
      return false; 
    }

    // Discord has a strict 2000 character limit per message.
    // Truncate to 1900 to leave room for the bold prefix.
    final safeMessage = message.length > 1900 ? '${message.substring(0, 1900)}...' : message;

    try {
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'content': '**New Feedback:**\n$safeMessage',
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
