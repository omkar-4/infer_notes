import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'block_model.dart';
import 'block_editor_controller.dart';
import 'block_item_widget.dart';
import 'slash_menu.dart';
import 'package:infer_notes/features/benchmarks/benchmark_engine.dart';

class CopyIntent extends Intent { const CopyIntent(); }
class CutIntent extends Intent { const CutIntent(); }
class PasteIntent extends Intent { const PasteIntent(); }
class SelectAllIntent extends Intent { const SelectAllIntent(); }

class BlockEditor extends StatefulWidget {
  final BlockEditorController controller;
  final String fontFamily;
  final double maxWidth;
  final ScrollController scrollController;

  const BlockEditor({
    super.key,
    required this.controller,
    required this.fontFamily,
    required this.maxWidth,
    required this.scrollController,
  });

  @override
  State<BlockEditor> createState() => BlockEditorState();
}

class BlockEditorState extends State<BlockEditor> {
  OverlayEntry? _slashMenuEntry;
  bool _isSelecting = false;
  int _selectStartIndex = -1;
  final Map<String, GlobalKey> blockKeys = {};

  void _runAndShowBenchmarks(BuildContext context) {
    final results = BenchmarkEngine.runAll();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.speed, color: Colors.deepOrange),
            SizedBox(width: 12),
            Text('Bare-Metal Performance Benchmarks'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Running decoupled micro-benchmarks against system baseline standards:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.5),
                },
                children: [
                  const TableRow(
                    children: [
                      TableCell(child: Text('Metric/Test Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      TableCell(child: Text('Latency', style: TextStyle(fontWeight: FontWeight.bold))),
                      TableCell(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  for (var res in results)
                    TableRow(
                      children: [
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(res.testName, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              res.durationMicroseconds >= 1000 
                                  ? '${(res.durationMicroseconds / 1000).toStringAsFixed(2)} ms'
                                  : '${res.durationMicroseconds.toStringAsFixed(0)} µs',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              res.status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: res.status.contains('Optimal') ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Recommendation: Keep block structures normalized. Large text dumps are parsed in sub-millisecond ranges using O(1) viewport virtualization.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSlashMenu(BuildContext context, Offset position, int index) {
    _hideSlashMenu();
    _slashMenuEntry = OverlayEntry(
      builder: (ctx) => SlashCommandMenu(
        position: position,
        onSelect: (choice) {
          if (choice == 'undo') {
            widget.controller.undo();
          } else if (choice == 'redo') {
            widget.controller.redo();
          } else if (choice == 'benchmark') {
            _runAndShowBenchmarks(context);
          } else if (choice is BlockType) {
            widget.controller.changeBlockType(index, choice);
          }
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

  int _getBlockIndexAtPosition(Offset globalPosition) {
    for (int i = 0; i < widget.controller.blocks.length; i++) {
      final block = widget.controller.blocks[i];
      final key = blockKeys[block.id];
      if (key == null || key.currentContext == null) continue;
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final position = box.localToGlobal(Offset.zero);
      final rect = position & box.size;
      if (rect.contains(Offset(rect.center.dx, globalPosition.dy))) {
        return i;
      }
    }
    return -1;
  }

  void _focusClosestBlock(Offset globalPosition) {
    double minDistance = double.infinity;
    MarkdownBlock? closestBlock;
    for (var block in widget.controller.blocks) {
      final key = blockKeys[block.id];
      if (key == null || key.currentContext == null) continue;
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final position = box.localToGlobal(Offset.zero);
      final blockCenterY = position.dy + box.size.height / 2;
      final distance = (globalPosition.dy - blockCenterY).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestBlock = block;
      }
    }
    if (closestBlock != null) {
      closestBlock.focusNode.requestFocus();
      closestBlock.controller.selection = TextSelection.collapsed(offset: closestBlock.controller.text.length);
    }
    widget.controller.clearSelection();
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
            _focusClosestBlock(details.globalPosition);
          },
          onPanStart: (details) {
            final index = _getBlockIndexAtPosition(details.globalPosition);
            if (index != -1) {
              _isSelecting = true;
              _selectStartIndex = index;
              widget.controller.selectRange(index, index);
            }
          },
          onPanUpdate: (details) {
            if (!_isSelecting) return;
            final index = _getBlockIndexAtPosition(details.globalPosition);
            if (index != -1) {
              widget.controller.selectRange(_selectStartIndex, index);
            }
          },
          onPanEnd: (_) {
            _isSelecting = false;
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              scrollController: widget.scrollController,
              shrinkWrap: false,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              physics: const AlwaysScrollableScrollPhysics(),
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
                final blockKey = blockKeys.putIfAbsent(block.id, () => GlobalKey());

                return Container(
                  key: ValueKey(block.id),
                  child: Container(
                    key: blockKey,
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
                      onCopy: () => widget.controller.copySelectedToClipboard(),
                      onCut: () {
                        widget.controller.copySelectedToClipboard();
                        widget.controller.deleteSelectedBlocks();
                      },
                      onPaste: () => widget.controller.pasteFromClipboard(index),
                      isMultiSelected: widget.controller.selectedBlockIds.length > 1,
                      onUndo: () => widget.controller.undo(),
                      onRedo: () => widget.controller.redo(),
                    ),
                  ),
                );
              },
            ),
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
        child: Scrollbar(
          controller: widget.scrollController,
          thumbVisibility: true,
          interactive: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: listContent,
            ),
          ),
        ),
      ),
    );
  }
}
