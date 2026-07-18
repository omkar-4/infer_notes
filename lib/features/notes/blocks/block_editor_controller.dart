import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infer_notes/features/aura/aura_metrics_engine.dart';
import 'block_model.dart';
import 'block_parser.dart';

class BlockEditorController extends ChangeNotifier {
  final List<MarkdownBlock> blocks = [];
  final Set<String> selectedBlockIds = {};
  
  // Keep track of the currently focused block index
  int _focusedIndex = -1;
  int get focusedIndex => _focusedIndex;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isHistoryOperation = false;
  
  Timer? _historyTimer;
  Timer? _metricsTimer;

  void loadMarkdown(String markdown) {
    for (var b in blocks) {
      b.dispose();
    }
    blocks.clear();
    selectedBlockIds.clear();
    
    final parsed = BlockParser.parse(markdown);
    blocks.addAll(parsed);
    _focusedIndex = -1;

    if (!_isHistoryOperation) {
      _undoStack.clear();
      _redoStack.clear();
      _undoStack.add(markdown);
    }

    notifyListeners();
  }

  String getMarkdown() {
    return BlockParser.serialize(blocks);
  }

  void setFocusedIndex(int index) {
    _focusedIndex = index;
    notifyListeners();
  }

  void clearSelection() {
    if (selectedBlockIds.isNotEmpty) {
      selectedBlockIds.clear();
      notifyListeners();
    }
  }

  void toggleBlockSelection(String id) {
    if (selectedBlockIds.contains(id)) {
      selectedBlockIds.remove(id);
    } else {
      selectedBlockIds.add(id);
    }
    notifyListeners();
  }

  void selectRange(int start, int end) {
    selectedBlockIds.clear();
    final min = start < end ? start : end;
    final max = start < end ? end : start;
    for (int i = min; i <= max; i++) {
      if (i >= 0 && i < blocks.length) {
        selectedBlockIds.add(blocks[i].id);
      }
    }
    notifyListeners();
  }

  void deleteSelectedBlocks() {
    if (selectedBlockIds.isEmpty) return;
    
    final toRemove = blocks.where((b) => selectedBlockIds.contains(b.id)).toList();
    if (toRemove.length == blocks.length) {
      // Don't leave it completely empty
      for (var b in blocks) b.dispose();
      blocks.clear();
      blocks.add(MarkdownBlock());
      _focusedIndex = 0;
      blocks[0].focusNode.requestFocus();
    } else {
      int firstRemovedIndex = blocks.indexWhere((b) => selectedBlockIds.contains(b.id));
      for (var b in toRemove) {
        blocks.remove(b);
        b.dispose();
      }
      _focusedIndex = (firstRemovedIndex < blocks.length) ? firstRemovedIndex : blocks.length - 1;
      if (_focusedIndex >= 0) {
        blocks[_focusedIndex].focusNode.requestFocus();
      }
    }
    selectedBlockIds.clear();
    saveHistoryStateDebounced();
    notifyListeners();
  }

  void changeBlockType(int index, BlockType newType) {
    if (index >= 0 && index < blocks.length) {
      blocks[index].type = newType;
      saveHistoryStateDebounced();
      notifyListeners();
    }
  }

  void splitBlock(int index, String remainingText) {
    final currentBlock = blocks[index];
    final newBlock = MarkdownBlock(
      type: currentBlock.type == BlockType.orderedList || currentBlock.type == BlockType.unorderedList
          ? currentBlock.type
          : BlockType.paragraph,
      content: remainingText,
    );
    
    blocks.insert(index + 1, newBlock);
    saveHistoryStateDebounced();
    notifyListeners();

    // Schedule focus request
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newBlock.focusNode.requestFocus();
      newBlock.controller.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  void mergeWithPrevious(int index) {
    if (index <= 0) return;
    
    final currentBlock = blocks[index];
    final prevBlock = blocks[index - 1];
    
    final originalPrevTextLength = prevBlock.controller.text.length;
    prevBlock.controller.text += currentBlock.controller.text;
    prevBlock.content = prevBlock.controller.text;

    blocks.removeAt(index);
    currentBlock.dispose();
    saveHistoryStateDebounced();
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      prevBlock.focusNode.requestFocus();
      prevBlock.controller.selection = TextSelection.collapsed(offset: originalPrevTextLength);
    });
  }

  Future<void> copySelectedToClipboard() async {
    final List<MarkdownBlock> list = [];
    if (selectedBlockIds.isEmpty && _focusedIndex >= 0) {
      list.add(blocks[_focusedIndex]);
    } else {
      for (var b in blocks) {
        if (selectedBlockIds.contains(b.id)) {
          list.add(b);
        }
      }
    }
    
    if (list.isNotEmpty) {
      final text = BlockParser.serialize(list);
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<void> pasteFromClipboard(int index) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;

    final parsedBlocks = BlockParser.parse(data.text!);
    
    // If the target block is empty, replace it. Otherwise insert after.
    final targetBlock = blocks[index];
    if (targetBlock.controller.text.isEmpty && targetBlock.type == BlockType.paragraph) {
      blocks.removeAt(index);
      targetBlock.dispose();
      blocks.insertAll(index, parsedBlocks);
    } else {
      blocks.insertAll(index + 1, parsedBlocks);
    }
    
    saveHistoryStateDebounced();
    notifyListeners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastPasted = parsedBlocks.last;
      lastPasted.focusNode.requestFocus();
    });
  }

  void saveHistoryStateDebounced() {
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 300), () {
      saveHistoryState();
    });
  }

  void saveHistoryState() {
    if (_isHistoryOperation) return;
    final currentMarkdown = getMarkdown();
    if (_undoStack.isEmpty || _undoStack.last != currentMarkdown) {
      _undoStack.add(currentMarkdown);
      if (_undoStack.length > 50) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
    }
  }

  void undo() {
    if (_undoStack.length < 2) return;
    _isHistoryOperation = true;
    final currentState = _undoStack.removeLast();
    _redoStack.add(currentState);
    final previousState = _undoStack.last;
    loadMarkdown(previousState);
    _isHistoryOperation = false;
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _isHistoryOperation = true;
    final nextState = _redoStack.removeLast();
    _undoStack.add(nextState);
    loadMarkdown(nextState);
    _isHistoryOperation = false;
  }

  void handleTextChanged(String id, String oldText, String newText) {
    final index = blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      blocks[index].content = newText;
    }
    
    // Instantly log keystroke difference for WPM
    final diff = newText.length - oldText.length;
    if (diff > 0) {
      AuraMetricsEngine().recordKeystrokes(diff);
    }
    
    // Debounce expensive total word count updates
    _metricsTimer?.cancel();
    _metricsTimer = Timer(const Duration(milliseconds: 150), () {
      final md = getMarkdown();
      AuraMetricsEngine().updateWordCount(md);
    });

    // Debounce history state snapshots to prevent lag
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 500), () {
      saveHistoryState();
    });
  }

  void selectOverlappingBlocks(Rect globalRect, Map<String, GlobalKey> blockKeys) {
    final newSelectedIds = <String>{};
    for (var block in blocks) {
      final key = blockKeys[block.id];
      if (key == null || key.currentContext == null) continue;
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final blockPosition = box.localToGlobal(Offset.zero);
      final blockRect = blockPosition & box.size;
      if (globalRect.overlaps(blockRect)) {
        newSelectedIds.add(block.id);
      }
    }
    
    final bool isIdentical = selectedBlockIds.length == newSelectedIds.length &&
        selectedBlockIds.every(newSelectedIds.contains);
        
    if (!isIdentical) {
      selectedBlockIds.clear();
      selectedBlockIds.addAll(newSelectedIds);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _metricsTimer?.cancel();
    for (var b in blocks) {
      b.dispose();
    }
    super.dispose();
  }
}
