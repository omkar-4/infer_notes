import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:flutter/foundation.dart';
import '../feedback/feedback_service.dart';

enum UpdaterState {
  idle,
  checking,
  downloading,
  verifyingIntegrity,
  readyToInstall,
}

enum UpdaterError {
  noInternetConnection,
  manifestNotFound,
  manifestFormatError,
  manifestFetchFailed,
  downloadFailed,
  checksumMismatch,
  installationFailed,
  miscError,
}

class UpdaterService {
  static UpdaterState state = UpdaterState.idle;
  static UpdaterError? lastError;
  static final ValueNotifier<double> downloadProgressNotifier = ValueNotifier(0.0);
  
  static void Function(UpdaterState, UpdaterError?)? onStateChange;
  
  static final String _archiveURL = 'https://raw.githubusercontent.com/omkar-4/infer_notes/main/latest.json';
  
  static Future<void> initialize() async {
    // Check quietly in the background
    _checkUpdates(silent: true);
  }

  static Future<void> checkUpdatesManually() async {
    await _checkUpdates(silent: false);
  }

  static Future<void> _checkUpdates({required bool silent}) async {
    if (state != UpdaterState.idle) return;
    state = UpdaterState.checking;
    lastError = null;
    onStateChange?.call(state, lastError);

    try {
      final response = await http.get(Uri.parse(_archiveURL));
      if (response.statusCode == 200) {
        final manifest = jsonDecode(response.body);
        
        if (!manifest.containsKey('version') || !manifest.containsKey('downloadUrl') || !manifest.containsKey('sha256')) {
           throw const FormatException('Manifest is missing required keys');
        }

        // Get current app version
        final packageInfo = await PackageInfo.fromPlatform();
        String currentVersionStr = packageInfo.version;
        // Sometimes packageInfo.version can be empty in debug, default to 0.0.0
        if (currentVersionStr.isEmpty) currentVersionStr = '0.0.0';
        
        final currentVersion = Version.parse(currentVersionStr);
        final latestVersion = Version.parse(manifest['version']);
        
        bool hasUpdate = latestVersion > currentVersion;
        
        if (hasUpdate) {
          await _downloadUpdate(manifest['downloadUrl'], manifest['sha256']);
        } else {
          state = UpdaterState.idle;
          if (!silent) {
            onStateChange?.call(state, lastError);
          }
        }
      } else if (response.statusCode == 404) {
        _handleError(UpdaterError.manifestNotFound, silent, details: '404 File Not Found on GitHub');
      } else {
        _handleError(UpdaterError.manifestFetchFailed, silent, details: 'HTTP ${response.statusCode}');
      }
    } on SocketException {
      _handleError(UpdaterError.noInternetConnection, silent, details: 'SocketException (No Internet)');
    } on FormatException catch (e) {
      _handleError(UpdaterError.manifestFormatError, silent, details: e.toString());
    } catch (e) {
      if (e.toString().contains('FormatException') || e.toString().contains('Version')) {
         _handleError(UpdaterError.manifestFormatError, silent, details: e.toString());
      } else {
         _handleError(UpdaterError.miscError, silent, details: e.toString());
      }
    }
  }

  static Future<void> _downloadUpdate(String url, String expectedHash) async {
    state = UpdaterState.downloading;
    downloadProgressNotifier.value = 0.0;
    onStateChange?.call(state, lastError);
    
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      
      final contentLength = response.contentLength ?? 1;
      int bytesDownloaded = 0;
      
      // We'll write to a .temp updater file
      final tempDir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}.infer_updater_temp');
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
      
      final tempFile = File('${tempDir.path}${Platform.pathSeparator}update.tmp');
      final sink = tempFile.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;
        downloadProgressNotifier.value = bytesDownloaded / contentLength;
      }
      
      await sink.flush();
      await sink.close();
      
      state = UpdaterState.verifyingIntegrity;
      onStateChange?.call(state, lastError);
      
      // Hash verification
      final bytes = await tempFile.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      
      if (hash != expectedHash) {
        tempFile.deleteSync(); // Corrupted file, destroy it
        _handleError(UpdaterError.checksumMismatch, false, details: 'Expected: $expectedHash\nActual: $hash');
        return;
      }
      
      state = UpdaterState.readyToInstall;
      onStateChange?.call(state, lastError);
      
    } catch (e) {
      _handleError(UpdaterError.downloadFailed, false, details: e.toString());
    }
  }

  static void _handleError(UpdaterError error, bool silent, {String? details}) {
    state = UpdaterState.idle;
    lastError = error;
    
    // Always send diagnostics regardless of silent mode
    FeedbackService.sendDiagnostic('Updater Error: ${error.name}', details ?? 'No details provided');

    if (!silent) {
      onStateChange?.call(state, lastError);
    }
  }

  /// Triggers the native platform installer if supported, safely isolated from core logic.
  static Future<void> executeInstall() async {
    if (state != UpdaterState.readyToInstall) return;

    final tempDir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}.infer_updater_temp');
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}update.tmp');

    if (!tempFile.existsSync()) return;

    if (Platform.isWindows) {
      // Execute the downloaded InnoSetup .exe installer
      await Process.start(tempFile.path, ['/SILENT']);
      exit(0); // Immediately terminate this app so the installer can overwrite files
    } else {
      // For MacOS/Linux, this would be isolated to their specific package managers (.dmg / .AppImage)
      // For now, no-op or throw unsupported.
    }
  }
}
