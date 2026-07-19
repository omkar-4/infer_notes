import 'package:flutter_test/flutter_test.dart';
import 'package:infer_notes/features/notes/blocks/block_model.dart';
import 'package:infer_notes/features/notes/blocks/block_parser.dart';

void main() {
  test('BlockParser round-trip test', () {
    const markdown = '# Heading 1\n## Heading 2\nSome text\n- List item\n1. Numbered item 1\n2. Numbered item 2\n> A quote\n```\ncode here\n```\n| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\n---';
    
    final blocks = BlockParser.parse(markdown);
    expect(blocks.length, 10);
    expect(blocks[0].type, BlockType.heading1);
    expect(blocks[0].controller.text, 'Heading 1');
    expect(blocks[1].type, BlockType.heading2);
    expect(blocks[1].controller.text, 'Heading 2');
    expect(blocks[2].type, BlockType.paragraph);
    expect(blocks[2].controller.text, 'Some text');
    expect(blocks[3].type, BlockType.unorderedList);
    expect(blocks[4].type, BlockType.orderedList);
    expect(blocks[4].controller.text, 'Numbered item 1');
    expect(blocks[5].type, BlockType.orderedList);
    expect(blocks[5].controller.text, 'Numbered item 2');
    expect(blocks[6].type, BlockType.blockquote);
    expect(blocks[7].type, BlockType.codeBlock);
    expect(blocks[7].controller.text, 'code here');
    expect(blocks[8].type, BlockType.table);
    expect(blocks[8].controller.text, '| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |');
    expect(blocks[9].type, BlockType.divider);

    final serialized = BlockParser.serialize(blocks);
    expect(serialized, markdown);
  });
}
