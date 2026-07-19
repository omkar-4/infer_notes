import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'block_model.dart';

class SlashCommandMenu extends StatefulWidget {
  final Offset position;
  final Function(dynamic choice) onSelect;
  final VoidCallback onDismiss;

  const SlashCommandMenu({
    super.key,
    required this.position,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<SlashCommandMenu> createState() => _SlashCommandMenuState();
}

class _SlashCommandMenuState extends State<SlashCommandMenu> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _options = [
    {'type': BlockType.paragraph, 'label': 'Text', 'icon': Icons.text_fields, 'desc': 'Plain text block'},
    {'type': BlockType.heading1, 'label': 'Heading 1', 'icon': Icons.looks_one, 'desc': 'Big section heading'},
    {'type': BlockType.heading2, 'label': 'Heading 2', 'icon': Icons.looks_two, 'desc': 'Medium section heading'},
    {'type': BlockType.heading3, 'label': 'Heading 3', 'icon': Icons.looks_3, 'desc': 'Small section heading'},
    {'type': BlockType.heading4, 'label': 'Heading 4', 'icon': Icons.looks_4, 'desc': 'Extra small heading'},
    {'type': BlockType.unorderedList, 'label': 'Bullet List', 'icon': Icons.format_list_bulleted, 'desc': 'Simple bulleted list'},
    {'type': BlockType.orderedList, 'label': 'Numbered List', 'icon': Icons.format_list_numbered, 'desc': 'Sequential list'},
    {'type': BlockType.blockquote, 'label': 'Quote', 'icon': Icons.format_quote, 'desc': 'Styled blockquote'},
    {'type': BlockType.codeBlock, 'label': 'Code Block', 'icon': Icons.code, 'desc': 'Code snippet block'},
    {'type': BlockType.divider, 'label': 'Divider', 'icon': Icons.horizontal_rule, 'desc': 'Visual separating line'},
    {'type': BlockType.table, 'label': 'Table', 'icon': Icons.grid_on, 'desc': 'Markdown table block'},
    {'type': 'undo', 'label': 'Undo', 'icon': Icons.undo, 'desc': 'Undo last action (Ctrl+Z)'},
    {'type': 'redo', 'label': 'Redo', 'icon': Icons.redo, 'desc': 'Redo last action (Ctrl+Shift+Z)'},
    {'type': 'benchmark', 'label': 'Run Benchmarks', 'icon': Icons.speed, 'desc': 'Exhaustive performance analysis'},
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuHeight = 300.0;
    const menuWidth = 250.0;

    double top = widget.position.dy;
    double left = widget.position.dx;

    if (top + menuHeight > screenSize.height) {
      top = top - menuHeight - 24;
      if (top < 0) top = 8;
    }

    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 16;
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              _selectedIndex = (_selectedIndex + 1) % _options.length;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() {
              _selectedIndex = (_selectedIndex - 1 + _options.length) % _options.length;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onSelect(_options[_selectedIndex]['type']);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onDismiss();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: menuWidth,
                constraints: const BoxConstraints(maxHeight: menuHeight),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedIndex;
                    final opt = _options[index];

                    return InkWell(
                      onTap: () => widget.onSelect(opt['type']),
                      child: Container(
                        color: isSelected ? Theme.of(context).focusColor : null,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(opt['icon'] as IconData, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['label'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    opt['desc'] as String,
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
