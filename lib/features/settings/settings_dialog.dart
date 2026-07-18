import 'package:flutter/material.dart';
import 'settings_service.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 450,
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Sidebar
            Material(
              color: Theme.of(context).cardColor,
              child: SizedBox(
                width: 150,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    ListTile(
                      selected: true,
                      selectedTileColor: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      leading: const Icon(Icons.bar_chart, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      horizontalTitleGap: 8,
                      title: const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Status Bar'),
                      ),
                    ),
                    // Future sections can go here
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status Bar Options', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildToggleRow(
                      context,
                      'Word Count',
                      SettingsService().showWordCount,
                      (val) => SettingsService().toggleWordCount(val),
                    ),
                    const SizedBox(height: 16),
                    _buildToggleRow(
                      context,
                      'WPM (Typing Speed)',
                      SettingsService().showWPM,
                      (val) => SettingsService().toggleWPM(val),
                    ),
                    const SizedBox(height: 16),
                    _buildToggleRow(
                      context,
                      'Live Timer',
                      SettingsService().showTimer,
                      (val) => SettingsService().toggleTimer(val),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(BuildContext context, String label, ValueNotifier<bool> notifier, ValueChanged<bool> onChanged) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, isEnabled, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(isEnabled ? '_*' : '*_', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    activeThumbColor: Colors.white,
                    overlayColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.hovered) ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    value: isEnabled,
                    onChanged: onChanged,
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }
}

