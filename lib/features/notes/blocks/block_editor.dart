import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'block_model.dart';
import 'block_editor_controller.dart';
import 'block_item_widget.dart';
import 'slash_menu.dart';

class CopyIntent extends Intent { const CopyIntent(); }
class CutIntent extends Intent { const CutIntent(); }
class PasteIntent extends Intent { const PasteIntent(); }
class SelectAllIntent extends Intent { const SelectAllIntent(); }

class BlockEditor extends StatefulWidget {
  final BlockEditorController controller;
  final String fontFamily;
  final double maxWidth;

  const BlockEditor({
    super.key,
    required this.controller,
    required this.fontFamily,
    required this.maxWidth,
  });

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  OverlayEntry? _slashMenuEntry;
  bool _isSelecting = false;
  int _selectStartIndex = -1;

  void _showSlashMenu(BuildContext context, Offset position, int index) {
    _hideSlashMenu();
    _slashMenuEntry = OverlayEntry(
      builder: (ctx) => SlashCommandMenu(
        position: position,
        onSelect: (type) {
          widget.controller.changeBlockType(index, type);
          final currentController = widget.controller.blocks[index].controller;
          if (currentController.text.endsWith('/')) {
            currentController.text = currentController.text.substring(0, currentController.text.length - 1);
            widget.controller.blocks[index].content = currentController.text;
          }
          _hideSlashMenu();
        },
        onDismiss: _hideSlashMenu,
      ),
    );
    Overlay.of(context).insert(_slashMenuEntry!);
  }

  void _hideSlashMenu() {
    _slashMenuEntry?.remove();
    _slashMenuEntry = null;
  }

  @override
  void dispose() {
    _hideSlashMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listContent = ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            final localY = details.localPosition.dy;
            const double averageBlockHeight = 44.0;
            int targetIndex = (localY / averageBlockHeight).floor();
            targetIndex = targetIndex.clamp(0, widget.controller.blocks.length - 1);
            widget.controller.blocks[targetIndex].focusNode.requestFocus();
            widget.controller.clearSelection();
          },
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.controller.blocks.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final block = widget.controller.blocks.removeAt(oldIndex);
                widget.controller.blocks.insert(newIndex, block);
                widget.controller.notifyListeners();
              });
            },
            itemBuilder: (context, index) {
              final block = widget.controller.blocks[index];
              final isSelected = widget.controller.selectedBlockIds.contains(block.id);

              return GestureDetector(
                key: ValueKey(block.id),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _isSelecting = true;
                  _selectStartIndex = index;
                  widget.controller.selectRange(index, index);
                },
                onPanUpdate: (details) {
                  if (!_isSelecting) return;
                  const double blockEstimateHeight = 44.0;
                  final double deltaY = details.localPosition.dy;
                  final int targetDelta = (deltaY / blockEstimateHeight).round();
                  final int targetIndex = (index + targetDelta).clamp(0, widget.controller.blocks.length - 1);
                  widget.controller.selectRange(_selectStartIndex, targetIndex);
                },
                onPanEnd: (_) {
                  _isSelecting = false;
                },
                child: BlockItemWidget(
                  block: block,
                  index: index,
                  isSelected: isSelected,
                  fontFamily: widget.fontFamily,
                  onFocus: () => widget.controller.setFocusedIndex(index),
                  onTextChanged: (oldText, newText) {
                    widget.controller.handleTextChanged(block.id, oldText, newText);
                  },
                  onMergeUp: () => widget.controller.mergeWithPrevious(index),
                  onSplit: (text) => widget.controller.splitBlock(index, text),
                  onTypeChanged: (type) => widget.controller.changeBlockType(index, type),
                  onSlashCommand: (pos) => _showSlashMenu(context, pos, index),
                  onArrowUp: () {
                    if (index > 0) {
                      widget.controller.blocks[index - 1].focusNode.requestFocus();
                    }
                  },
                  onArrowDown: () {
                    if (index < widget.controller.blocks.length - 1) {
                      widget.controller.blocks[index + 1].focusNode.requestFocus();
                    }
                  },
                  onSelectAbove: (isShift) {
                    if (index > 0) {
                      widget.controller.selectRange(index, index - 1);
                    }
                  },
                  onSelectBelow: (isShift) {
                    if (index < widget.controller.blocks.length - 1) {
                      widget.controller.selectRange(index, index + 1);
                    }
                  },
                  onSelectAll: () => widget.controller.selectRange(0, widget.controller.blocks.length - 1),
                ),
              );
            },
          ),
        );
      },
    );

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX): const CutIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA): const SelectAllIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyC): const CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyX): const CutIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): const PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA): const SelectAllIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CopyIntent: CallbackAction<CopyIntent>(
            onInvoke: (_) {
              widget.controller.copySelectedToClipboard();
              return null;
            },
          ),
          CutIntent: CallbackAction<CutIntent>(
            onInvoke: (_) {
              widget.controller.copySelectedToClipboard();
              widget.controller.deleteSelectedBlocks();
              return null;
            },
          ),
          PasteIntent: CallbackAction<PasteIntent>(
            onInvoke: (_) {
              final focusedIndex = widget.controller.focusedIndex;
              if (focusedIndex >= 0) {
                widget.controller.pasteFromClipboard(focusedIndex);
              }
              return null;
            },
          ),
          SelectAllIntent: CallbackAction<SelectAllIntent>(
            onInvoke: (_) {
              widget.controller.selectRange(0, widget.controller.blocks.length - 1);
              return null;
            },
          ),
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: listContent,
          ),
        ),
      ),
    );
  }
}
