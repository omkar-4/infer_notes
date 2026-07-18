import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nlp_engine.dart';

class SuggestionOverlay extends StatefulWidget {
  final Widget child;
  final TextEditingController controller;
  final FocusNode focusNode;
  
  const SuggestionOverlay({
    super.key,
    required this.child,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<SuggestionOverlay> createState() => _SuggestionOverlayState();
}

class _SuggestionOverlayState extends State<SuggestionOverlay> {
  OverlayEntry? _overlayEntry;
  String? _currentSuggestion;
  String? _suggestionSuffix;
  String? _currentWord;
  int _startIndex = -1;
  final GlobalKey _textFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
    NlpEngine.initialize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    if (!widget.focusNode.hasFocus) return;

    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (selection.isValid && selection.isCollapsed) {
      final cursor = selection.baseOffset;
      
      int start = -1;
      for (int i = cursor - 1; i >= 0; i--) {
        if (RegExp(r'\s').hasMatch(text[i])) {
          start = i;
          break;
        }
      }
      
      final currentWord = text.substring(start + 1, cursor);
      if (currentWord.length >= 3) {
        final suggestion = NlpEngine.getSuggestion(currentWord);
        if (suggestion != null && suggestion != currentWord) {
          setState(() {
            _currentWord = currentWord;
            _currentSuggestion = suggestion;
            if (suggestion.toLowerCase().startsWith(currentWord.toLowerCase())) {
              _suggestionSuffix = suggestion.substring(currentWord.length);
            } else {
              _suggestionSuffix = suggestion; 
            }
            _startIndex = start + 1;
          });
          _showOverlay();
          return;
        }
      }
    }
    
    setState(() {
      _currentSuggestion = null;
      _suggestionSuffix = null;
    });
    _hideOverlay();
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        if (_currentSuggestion == null) return const SizedBox.shrink();

        final RenderBox? renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return const SizedBox.shrink();

        final offset = renderBox.localToGlobal(Offset.zero);
        
        Offset cursorOffset = Offset.zero;
        try {
          final painter = TextPainter(
            text: TextSpan(
              text: widget.controller.text.substring(0, widget.controller.selection.baseOffset),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            textDirection: TextDirection.ltr,
          );
          painter.layout(maxWidth: renderBox.size.width - 32); 
          
          final pos = painter.getOffsetForCaret(
            TextPosition(offset: widget.controller.selection.baseOffset), 
            Rect.zero
          );
          
          cursorOffset = Offset(pos.dx + 16, pos.dy + 8);
        } catch (_) {}

        return Positioned(
          left: offset.dx + cursorOffset.dx + 5,
          top: offset.dy + cursorOffset.dy + 25,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            color: Theme.of(context).cardColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _suggestionSuffix == _currentSuggestion 
                        ? _currentSuggestion! 
                        : _currentWord! + _suggestionSuffix!,
                    style: TextStyle(
                      color: _suggestionSuffix == _currentSuggestion ? Colors.orange : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Tab', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _acceptSuggestion() {
    if (_currentSuggestion != null && _startIndex != -1) {
      final cursor = widget.controller.selection.baseOffset;
      final newText = widget.controller.text.replaceRange(_startIndex, cursor, _currentSuggestion!);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: _startIndex + _currentSuggestion!.length),
      );
      _hideOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
          if (_currentSuggestion != null) {
            _acceptSuggestion();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: KeyedSubtree(
        key: _textFieldKey,
        child: widget.child,
      ),
    );
  }
}
