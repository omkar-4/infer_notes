import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'block_model.dart';

class BlockWidget extends StatefulWidget {
  final MarkdownBlock block;
  final int index;
  final VoidCallback onMergeUp;
  final Function(String text) onSplit;
  final Function(String text) onPaste;
  final Function(BlockType type) onTypeChanged;
  final Function(Offset position) onSlashCommand;
  final VoidCallback onArrowUp;
  final VoidCallback onArrowDown;
  final VoidCallback onFocus;

  const BlockWidget({
    super.key,
    required this.block,
    required this.index,
    required this.onMergeUp,
    required this.onSplit,
    required this.onPaste,
    required this.onTypeChanged,
    required this.onSlashCommand,
    required this.onArrowUp,
    required this.onArrowDown,
    required this.onFocus,
  });

  @override
  State<BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<BlockWidget> {
  late InlineCodeTextController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InlineCodeTextController(text: widget.block.content);
    widget.block.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.content != _controller.text) {
      final oldSelection = _controller.selection;
      _controller.text = widget.block.content;
      // Try to maintain selection if valid
      if (oldSelection.isValid && oldSelection.baseOffset <= _controller.text.length) {
        _controller.selection = oldSelection;
      } else {
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    }
  }

  final ValueNotifier<bool> _isHovering = ValueNotifier(false);

  void _onFocusChange() {
    setState(() {}); // Rebuild to show/hide hint text
    if (widget.block.focusNode.hasFocus) {
      if (widget.block.requestedCaretX != null) {
        final offsetToRestore = widget.block.requestedCaretX!.toInt();
        widget.block.requestedCaretX = null; // Reset
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controller.selection = TextSelection.collapsed(offset: offsetToRestore);
          }
        });
      }
      widget.onFocus();
    }
  }

  @override
  void dispose() {
    widget.block.focusNode.removeListener(_onFocusChange);
    _isHovering.dispose();
    // controller is disposed by block model
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.selection.baseOffset == 0 && _controller.selection.extentOffset == 0) {
          if (widget.block.type != BlockType.paragraph) {
            // Revert to paragraph first
            widget.onTypeChanged(BlockType.paragraph);
            return KeyEventResult.handled;
          } else {
            // Merge up
            widget.onMergeUp();
            return KeyEventResult.handled;
          }
        }
      }
      
      if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
        final text = _controller.text;
        final selection = _controller.selection;
        String remaining = '';
        if (selection.isValid && selection.isCollapsed) {
          remaining = text.substring(selection.baseOffset);
          _controller.text = text.substring(0, selection.baseOffset);
          widget.block.updateContent(_controller.text);
        }
        widget.onSplit(remaining);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_isFirstLine(_controller.selection.baseOffset)) {
          widget.onArrowUp();
          return KeyEventResult.handled;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_isLastLine(_controller.selection.baseOffset)) {
          widget.onArrowDown();
          return KeyEventResult.handled;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_controller.selection.baseOffset == 0) {
          widget.onArrowUp();
          return KeyEventResult.handled;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_controller.selection.baseOffset == _controller.text.length) {
          widget.onArrowDown();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  bool _isFirstLine(int offset) {
    if (_controller.text.isEmpty || offset == 0) return true;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return true;
    final double maxWidth = renderBox.size.width - 50;
    final textPainter = TextPainter(
      text: TextSpan(text: _controller.text, style: _getTextStyle(context)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: maxWidth > 0 ? maxWidth : double.infinity);
    final offsetPosition = textPainter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
    return offsetPosition.dy < textPainter.preferredLineHeight;
  }

  bool _isLastLine(int offset) {
    if (_controller.text.isEmpty || offset == _controller.text.length) return true;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return true; 
    final double maxWidth = renderBox.size.width - 50;
    final textPainter = TextPainter(
      text: TextSpan(text: _controller.text, style: _getTextStyle(context)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: maxWidth > 0 ? maxWidth : double.infinity);
    final offsetPosition = textPainter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
    return offsetPosition.dy >= (textPainter.height - (textPainter.preferredLineHeight * 1.5));
  }

  void _onTextChanged(String value) {
    if (value.contains('\n')) {
      widget.onPaste(value);
      return;
    }
    
    widget.block.updateContent(value);
    
    // Check for markdown transformations
    if (widget.block.type == BlockType.paragraph) {
      if (value == '# ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.heading1);
      } else if (value == '## ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.heading2);
      } else if (value == '### ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.heading3);
      } else if (value == '#### ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.heading4);
      } else if (value == '- ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.unorderedList);
      } else if (value == '1. ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.orderedList);
      } else if (value == '> ') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.blockquote);
      } else if (value == '---') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.divider);
      } else if (value == '```') {
        _controller.text = '';
        widget.onTypeChanged(BlockType.codeBlock);
      }
    }

    if (value.endsWith('/')) {
      // Trigger slash command
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset(0, renderBox.size.height));
      widget.onSlashCommand(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    // Use our custom controller for normal text, but for others we just style the standard TextField
    final textField = Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: _controller,
        focusNode: widget.block.focusNode,
        onChanged: _onTextChanged,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: _getTextStyle(context),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          border: InputBorder.none,
          hintText: widget.block.type == BlockType.paragraph ? "Type '/' for commands" : null,
          hintStyle: TextStyle(
            color: (widget.block.type == BlockType.paragraph && widget.block.focusNode.hasFocus) 
                ? Colors.grey.withValues(alpha: 0.5) 
                : Colors.transparent,
          ),
        ),
      ),
    );

    switch (widget.block.type) {
      case BlockType.unorderedList:
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10.0, right: 8.0, left: 16.0),
              child: Icon(Icons.circle, size: 6),
            ),
            Expanded(child: textField),
          ],
        );
        break;
      case BlockType.orderedList:
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6.0, right: 8.0, left: 16.0),
              child: Text('${widget.index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: textField),
          ],
        );
        break;
      case BlockType.blockquote:
        child = Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 4)),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ),
          padding: const EdgeInsets.only(left: 12.0),
          child: textField,
        );
        break;
      case BlockType.codeBlock:
        child = Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(12.0),
          child: textField,
        );
        break;
      case BlockType.divider:
        child = Column(
          children: [
            const Divider(height: 24, thickness: 2),
            // We need a hidden text field so it can still receive focus and be deleted
            SizedBox(height: 0, child: textField), 
          ],
        );
        break;
      default:
        child = textField;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: MouseRegion(
        onEnter: (_) => _isHovering.value = true,
        onExit: (_) => _isHovering.value = false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isHovering,
              builder: (context, isHovering, child) {
                return Opacity(
                  opacity: isHovering ? 1.0 : 0.0,
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, right: 8.0, left: 4.0),
                        child: Icon(Icons.drag_indicator, size: 18, color: Colors.grey.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  TextStyle _getTextStyle(BuildContext context) {
    switch (widget.block.type) {
      case BlockType.heading1:
        return const TextStyle(fontSize: 32, fontWeight: FontWeight.bold);
      case BlockType.heading2:
        return const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
      case BlockType.heading3:
        return const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
      case BlockType.heading4:
        return const TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
      case BlockType.blockquote:
        return const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey);
      case BlockType.codeBlock:
        return const TextStyle(fontFamily: 'monospace', fontSize: 14);
      default:
        return const TextStyle(fontSize: 16);
    }
  }
}

// Custom controller to handle inline `code` highlighting
class InlineCodeTextController extends TextEditingController {
  InlineCodeTextController({super.text});

  static final RegExp _codeExp = RegExp(r'`([^`]+)`');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final String sourceText = text;
    final List<InlineSpan> children = [];
    
    int lastMatchEnd = 0;

    for (final Match match in _codeExp.allMatches(sourceText)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(text: sourceText.substring(lastMatchEnd, match.start), style: style));
      }
      // Add the matched code block
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Text(
              match.group(1)!,
              style: style?.copyWith(fontFamily: 'monospace', color: Theme.of(context).primaryColor),
            ),
          ),
        )
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < sourceText.length) {
      children.add(TextSpan(text: sourceText.substring(lastMatchEnd), style: style));
    }

    return TextSpan(children: children, style: style);
  }
}
