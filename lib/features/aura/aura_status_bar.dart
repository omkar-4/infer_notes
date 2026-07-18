import 'dart:async';
import 'package:flutter/material.dart';
import 'aura_metrics_engine.dart';
import '../settings/settings_service.dart';

class AuraStatusBar extends StatefulWidget {
  final String filePath;
  const AuraStatusBar({super.key, required this.filePath});

  @override
  State<AuraStatusBar> createState() => _AuraStatusBarState();
}

class _AuraStatusBarState extends State<AuraStatusBar> {
  StreamSubscription? _sub;
  final AuraMetricsEngine _engine = AuraMetricsEngine();

  @override
  void initState() {
    super.initState();
    _sub = _engine.onMetricsUpdated.listen((_) {
      if (mounted) setState(() {});
    });
    
    SettingsService().showWordCount.addListener(_onSettingChanged);
    SettingsService().showWPM.addListener(_onSettingChanged);
    SettingsService().showTimer.addListener(_onSettingChanged);
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AuraStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    SettingsService().showWordCount.removeListener(_onSettingChanged);
    SettingsService().showWPM.removeListener(_onSettingChanged);
    SettingsService().showTimer.removeListener(_onSettingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wpm = _engine.currentWPM;
    final words = _engine.currentWordCount;
    final timeStr = _engine.getFormattedTime(widget.filePath);

    final showWords = SettingsService().showWordCount.value;
    final showSpeed = SettingsService().showWPM.value;
    final showTime = SettingsService().showTimer.value;

    if (!showWords && !showSpeed && !showTime) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showWords) _buildMetric(Icons.text_snippet_outlined, "$words words"),
          if (showWords && (showSpeed || showTime)) const SizedBox(width: 16),
          if (showSpeed) _buildMetric(Icons.speed_outlined, "$wpm WPM"),
          if (showSpeed && showTime) const SizedBox(width: 16),
          if (showTime) _buildMetric(Icons.timer_outlined, timeStr),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
