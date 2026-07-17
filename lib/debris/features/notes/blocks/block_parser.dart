import 'block_model.dart';

class BlockParser {
  static final RegExp _olRegex = RegExp(r'^(\d+|[a-zA-Z]+|[ivxlcdmIVXLCDM]+)\.\s(.*)');

  static List<MarkdownBlock> parse(String markdown) {
    if (markdown.isEmpty) return [MarkdownBlock()];

    final List<MarkdownBlock> blocks = [];
    final lines = markdown.split('\n');

    bool inCodeBlock = false;
    String codeBuffer = '';

    for (var line in lines) {
      if (inCodeBlock) {
        if (line.trim() == '```') {
          blocks.add(MarkdownBlock(type: BlockType.codeBlock, content: codeBuffer.trimRight()));
          inCodeBlock = false;
          codeBuffer = '';
        } else {
          codeBuffer += '$line\n';
        }
        continue;
      }

      if (line.trim().startsWith('```')) {
        inCodeBlock = true;
        codeBuffer = '';
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
      }

      if (line.startsWith('> ')) {
        blocks.add(MarkdownBlock(type: BlockType.blockquote, content: line.substring(2)));
        continue;
      }

      // Check for ordered list (1., a., i., I.)
      final match = _olRegex.firstMatch(line);
      if (match != null) {
        // match.group(1) is the list marker (e.g., '1', 'a', 'i')
        // match.group(2) is the content
        // We'll store the marker as part of the content for now to avoid losing data, 
        // OR we can just store the content and reconstruct numbers later.
        // For simplicity in a block editor, let's keep the marker in the content so the user sees "1. hello"
        // Wait, if we keep the marker, it behaves like a paragraph. We need to strip it.
        // Let's store the raw content and rely on the UI to show the number.
        blocks.add(MarkdownBlock(type: BlockType.orderedList, content: match.group(2) ?? ''));
        continue;
      }

      blocks.add(MarkdownBlock(type: BlockType.paragraph, content: line));
    }

    if (inCodeBlock) {
      blocks.add(MarkdownBlock(type: BlockType.codeBlock, content: codeBuffer.trimRight()));
    }

    if (blocks.isEmpty) {
      blocks.add(MarkdownBlock());
    }

    return blocks;
  }

  static String serialize(List<MarkdownBlock> blocks) {
    if (blocks.isEmpty) return '';
    
    final StringBuffer buffer = StringBuffer();
    
    int olCounter = 1;

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final content = block.content; // get latest text from UI state

      switch (block.type) {
        case BlockType.paragraph:
          buffer.write(content);
          olCounter = 1; // reset ordered list counter
          break;
        case BlockType.heading1:
          buffer.write('# $content');
          olCounter = 1;
          break;
        case BlockType.heading2:
          buffer.write('## $content');
          olCounter = 1;
          break;
        case BlockType.heading3:
          buffer.write('### $content');
          olCounter = 1;
          break;
        case BlockType.heading4:
          buffer.write('#### $content');
          olCounter = 1;
          break;
        case BlockType.unorderedList:
          buffer.write('- $content');
          olCounter = 1;
          break;
        case BlockType.orderedList:
          buffer.write('$olCounter. $content');
          olCounter++;
          break;
        case BlockType.blockquote:
          buffer.write('> $content');
          olCounter = 1;
          break;
        case BlockType.divider:
          buffer.write('---');
          olCounter = 1;
          break;
        case BlockType.codeBlock:
          buffer.write('```\n$content\n```');
          olCounter = 1;
          break;
      }
      
      if (i < blocks.length - 1) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }
}
