import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'markdown_editing_controller.dart';

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
  table,
}

class MarkdownBlock {
  final String id;
  BlockType type;
  String content;
  
  late final TextEditingController controller;
  late final FocusNode focusNode;

  MarkdownBlock({
    String? id,
    this.type = BlockType.paragraph,
    this.content = '',
  }) : id = id ?? const Uuid().v4() {
    controller = MarkdownEditingController(text: content);
    focusNode = FocusNode();
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
