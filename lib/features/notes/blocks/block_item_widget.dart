import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'block_model.dart';

class BlockItemWidget extends StatefulWidget {
  final MarkdownBlock block;
  final int index;
  final bool isSelected;
  final String fontFamily;
  final VoidCallback onFocus;
  final Function(String oldText, String newText) onTextChanged;
  final VoidCallback onMergeUp;
  final Function(String text) onSplit;
  final Function(BlockType type) onTypeChanged;
  final Function(Offset position) onSlashCommand;
  final VoidCallback onArrowUp;
  final VoidCallback onArrowDown;
  final Function(bool isShiftPressed) onSelectAbove;
  final Function(bool isShiftPressed) onSelectBelow;
  final VoidCallback onSelectAll;
  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onPaste;
  final bool isMultiSelected;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const BlockItemWidget({
    super.key,
    required this.block,
    required this.index,
    required this.isSelected,
    required this.fontFamily,
    required this.onFocus,
    required this.onTextChanged,
    required this.onMergeUp,
    required this.onSplit,
    required this.onTypeChanged,
    required this.onSlashCommand,
    required this.onArrowUp,
    required this.onArrowDown,
    required this.onSelectAbove,
    required this.onSelectBelow,
    required this.onSelectAll,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.isMultiSelected,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  State<BlockItemWidget> createState() => _BlockItemWidgetState();
}

class _BlockItemWidgetState extends State<BlockItemWidget> {
  final ValueNotifier<bool> _isHovering = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    widget.block.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {}); // Toggle hint text visibility
    if (widget.block.focusNode.hasFocus) {
      widget.onFocus();
    }
  }

  @override
  void dispose() {
    widget.block.focusNode.removeListener(_onFocusChange);
    _isHovering.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (isShiftPressed) {
          widget.onRedo();
        } else {
          widget.onUndo();
        }
        return KeyEventResult.handled;
      }
      if (widget.isMultiSelected) {
        if (event.logicalKey == LogicalKeyboardKey.keyC) {
          widget.onCopy();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyX) {
          widget.onCut();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyV) {
          widget.onPaste();
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        final text = widget.block.controller.text;
        final selection = widget.block.controller.selection;
        if (selection.baseOffset == 0 && selection.extentOffset == text.length) {
          widget.onSelectAll();
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (widget.block.controller.selection.baseOffset == 0 && widget.block.controller.selection.extentOffset == 0) {
        if (widget.block.type != BlockType.paragraph) {
          widget.onTypeChanged(BlockType.paragraph);
          return KeyEventResult.handled;
        } else {
          widget.onMergeUp();
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (isShiftPressed) {
        return KeyEventResult.ignored; // Let system add newline
      }
      final text = widget.block.controller.text;
      final selection = widget.block.controller.selection;
      String remaining = '';
      if (selection.isValid) {
        remaining = text.substring(selection.baseOffset);
        widget.block.controller.text = text.substring(0, selection.baseOffset);
        widget.block.content = widget.block.controller.text;
      }
      widget.onSplit(remaining);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (isShiftPressed) {
        widget.onSelectAbove(true);
        return KeyEventResult.handled;
      }
      widget.onArrowUp();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isShiftPressed) {
        widget.onSelectBelow(true);
        return KeyEventResult.handled;
      }
      widget.onArrowDown();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onTextChanged(String value) {
    final oldText = widget.block.content;
    widget.block.content = value;
    widget.onTextChanged(oldText, value);

    if (value.startsWith('# ')) {
      widget.block.controller.text = value.substring(2);
      widget.onTypeChanged(BlockType.heading1);
    } else if (value.startsWith('## ')) {
      widget.block.controller.text = value.substring(3);
      widget.onTypeChanged(BlockType.heading2);
    } else if (value.startsWith('### ')) {
      widget.block.controller.text = value.substring(4);
      widget.onTypeChanged(BlockType.heading3);
    } else if (value.startsWith('#### ')) {
      widget.block.controller.text = value.substring(5);
      widget.onTypeChanged(BlockType.heading4);
    } else if (value.startsWith('- ')) {
      widget.block.controller.text = value.substring(2);
      widget.onTypeChanged(BlockType.unorderedList);
    } else if (value.startsWith('* ')) {
      widget.block.controller.text = value.substring(2);
      widget.onTypeChanged(BlockType.unorderedList);
    } else if (value.startsWith('1. ')) {
      widget.block.controller.text = value.substring(3);
      widget.onTypeChanged(BlockType.orderedList);
    } else if (value.startsWith('> ')) {
      widget.block.controller.text = value.substring(2);
      widget.onTypeChanged(BlockType.blockquote);
    } else if (value == '---') {
      widget.block.controller.text = '';
      widget.onTypeChanged(BlockType.divider);
    } else if (value == '```') {
      widget.block.controller.text = '';
      widget.onTypeChanged(BlockType.codeBlock);
    }

    if (value.endsWith('/')) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset(0, renderBox.size.height));
        widget.onSlashCommand(position);
      }
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final themeColor = Theme.of(context).textTheme.bodyMedium?.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);
    final paint = Paint()
      ..color = themeColor
      ..isAntiAlias = true;

    TextStyle base = TextStyle(fontFamily: widget.fontFamily, foreground: paint);
    switch (widget.block.type) {
      case BlockType.heading1:
        return base.copyWith(fontSize: 28, fontWeight: FontWeight.bold);
      case BlockType.heading2:
        return base.copyWith(fontSize: 22, fontWeight: FontWeight.bold);
      case BlockType.heading3:
        return base.copyWith(fontSize: 18, fontWeight: FontWeight.bold);
      case BlockType.heading4:
        return base.copyWith(fontSize: 15, fontWeight: FontWeight.bold);
      case BlockType.blockquote:
        final quotePaint = Paint()
          ..color = Colors.grey
          ..isAntiAlias = true;
        return base.copyWith(fontSize: 16, fontStyle: FontStyle.italic, foreground: quotePaint);
      case BlockType.codeBlock:
        return TextStyle(fontFamily: 'monospace', fontSize: 13, foreground: paint);
      default:
        return base.copyWith(fontSize: 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.block.focusNode.hasFocus;
    final isEmpty = widget.block.controller.text.isEmpty;
    final showHint = isFocused && isEmpty && widget.block.type == BlockType.paragraph;

    Widget inputField = Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: widget.block.controller,
        focusNode: widget.block.focusNode,
        onChanged: _onTextChanged,
        maxLines: null,
        style: _getTextStyle(context),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          border: InputBorder.none,
          hintText: showHint ? "Type '/' for commands" : null,
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
        ),
      ),
    );

    Widget content;
    switch (widget.block.type) {
      case BlockType.unorderedList:
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8.0, right: 8.0, left: 8.0),
              child: Icon(Icons.circle, size: 6),
            ),
            Expanded(child: inputField),
          ],
        );
        break;
      case BlockType.orderedList:
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 8.0, left: 8.0),
              child: Text('${widget.index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: inputField),
          ],
        );
        break;
      case BlockType.blockquote:
        content = Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 3)),
          ),
          padding: const EdgeInsets.only(left: 12.0),
          child: inputField,
        );
        break;
      case BlockType.codeBlock:
        content = Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(8.0),
          child: inputField,
        );
        break;
      case BlockType.divider:
        content = Column(
          children: [
            const Divider(height: 20, thickness: 1.5),
            SizedBox(height: 0, child: inputField),
          ],
        );
        break;
      default:
        content = inputField;
    }

    return MouseRegion(
      onEnter: (_) => _isHovering.value = true,
      onExit: (_) => _isHovering.value = false,
      child: Container(
        color: widget.isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isHovering,
              builder: (context, isHovering, _) {
                return Opacity(
                  opacity: isHovering ? 1.0 : 0.0,
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
