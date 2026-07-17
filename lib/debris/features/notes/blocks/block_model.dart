import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  heading4,
  unorderedList,
  orderedList,
  blockquote,
  divider,
  codeBlock,
}

class MarkdownBlock {
  final String id;
  BlockType type;
  
  // This holds the clean text (e.g. without the "# " prefix)
  String content; 
  
  final TextEditingController controller;
  final FocusNode focusNode;
  double? requestedCaretX;

  MarkdownBlock({
    String? id,
    this.type = BlockType.paragraph,
    this.content = '',
  })  : id = id ?? const Uuid().v4(),
        controller = TextEditingController(text: content),
        focusNode = FocusNode();

  void updateContent(String newContent) {
    content = newContent;
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
