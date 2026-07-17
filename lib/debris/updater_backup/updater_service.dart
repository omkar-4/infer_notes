import 'package:desktop_updater/desktop_updater.dart';

class UpdaterService {
  static DesktopUpdaterController? controller;

  /// Initializes the modern desktop updater engine.
  static Future<void> initialize() async {
    // Point to a standard app-archive JSON file hosted on GitHub or your server
    const String archiveURL = 'https://raw.githubusercontent.com/username/infer_notes/main/app-archive.json';
    
    controller = DesktopUpdaterController(
      appArchiveUrl: Uri.parse(archiveURL),
    );
    
    // desktop_updater handles background checking natively when the controller is attached to the UI
  }

  /// Triggers a visible, manual check for updates when invoked by the user.
  static Future<void> checkUpdatesManually() async {
    // desktop_updater generally relies on the DesktopUpdateWidget in the UI to present checks,
    // but you can force a refresh on the controller if needed.
    // Ensure the controller is attached to a DesktopUpdateWidget in your main UI!
  }
}
