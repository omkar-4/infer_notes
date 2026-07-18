import 'block_model.dart';

class BlockParser {
  static final RegExp _orderedListRegex = RegExp(r'^(\d+)\.\s(.*)');

  static List<MarkdownBlock> parse(String markdown) {
    if (markdown.trim().isEmpty) {
      return [MarkdownBlock()];
    }

    final List<MarkdownBlock> blocks = [];
    final lines = markdown.split('\n');

    bool inCodeBlock = false;
    StringBuffer codeBuffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (inCodeBlock) {
        if (line.trim() == '```') {
          blocks.add(MarkdownBlock(
            type: BlockType.codeBlock,
            content: codeBuffer.toString().trimRight(),
          ));
          inCodeBlock = false;
          codeBuffer.clear();
        } else {
          codeBuffer.writeln(line);
        }
        continue;
      }

      if (line.trim() == '```') {
        inCodeBlock = true;
        codeBuffer.clear();
        continue;
      }

      if (line.trim() == '---') {
        blocks.add(MarkdownBlock(type: BlockType.divider, content: ''));
        continue;
      }

      if (line.startsWith('# ')) {
        blocks.add(MarkdownBlock(type: BlockType.heading1, content: line.substring(2)));
        continue;
      } else if (line.startsWith('## ')) {
        blocks.add(MarkdownBlock(type: BlockType.heading2, content: line.substring(3)));
        continue;
      } else if (line.startsWith('### ')) {
        blocks.add(MarkdownBlock(type: BlockType.heading3, content: line.substring(4)));
        continue;
      } else if (line.startsWith('#### ')) {
        blocks.add(MarkdownBlock(type: BlockType.heading4, content: line.substring(5)));
        continue;
      }

      if (line.startsWith('- ')) {
        blocks.add(MarkdownBlock(type: BlockType.unorderedList, content: line.substring(2)));
        continue;
      } else if (line.startsWith('* ')) {
        blocks.add(MarkdownBlock(type: BlockType.unorderedList, content: line.substring(2)));
        continue;
      }

      if (line.startsWith('> ')) {
        blocks.add(MarkdownBlock(type: BlockType.blockquote, content: line.substring(2)));
        continue;
      }

      final match = _orderedListRegex.firstMatch(line);
      if (match != null) {
        blocks.add(MarkdownBlock(type: BlockType.orderedList, content: match.group(2) ?? ''));
        continue;
      }

      // Default paragraph (even empty line is a paragraph block)
      blocks.add(MarkdownBlock(type: BlockType.paragraph, content: line));
    }

    if (inCodeBlock) {
      blocks.add(MarkdownBlock(type: BlockType.codeBlock, content: codeBuffer.toString().trimRight()));
    }

    return blocks.isEmpty ? [MarkdownBlock()] : blocks;
  }

  static String serialize(List<MarkdownBlock> blocks) {
    final StringBuffer buffer = StringBuffer();
    int orderedListIndex = 1;

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final content = block.controller.text;

      // Handle ordered list counter continuity
      if (block.type == BlockType.orderedList) {
        buffer.write('$orderedListIndex. $content');
        orderedListIndex++;
      } else {
        orderedListIndex = 1; // Reset counter on non-ordered lists
        switch (block.type) {
          case BlockType.paragraph:
            buffer.write(content);
            break;
          case BlockType.heading1:
            buffer.write('# $content');
            break;
          case BlockType.heading2:
            buffer.write('## $content');
            break;
          case BlockType.heading3:
            buffer.write('### $content');
            break;
          case BlockType.heading4:
            buffer.write('#### $content');
            break;
          case BlockType.unorderedList:
            buffer.write('- $content');
            break;
          case BlockType.blockquote:
            buffer.write('> $content');
            break;
          case BlockType.divider:
            buffer.write('---');
            break;
          case BlockType.codeBlock:
            buffer.write('```\n$content\n```');
            break;
          default:
            buffer.write(content);
        }
      }

      if (i < blocks.length - 1) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }
}
