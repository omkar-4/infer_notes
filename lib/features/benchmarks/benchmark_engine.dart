import 'dart:ui';
import '../notes/blocks/block_model.dart';
import '../notes/blocks/block_parser.dart';
import '../notes/blocks/block_editor_controller.dart';

class BenchmarkResult {
  final String testName;
  final double durationMicroseconds;
  final String status;
  final String standard;

  BenchmarkResult({
    required this.testName,
    required this.durationMicroseconds,
    required this.status,
    required this.standard,
  });
}

class BenchmarkEngine {
  static List<BenchmarkResult> runAll() {
    final results = <BenchmarkResult>[];
    
    results.add(_benchmarkSerialization());
    results.add(_benchmarkParsing());
    results.add(_benchmarkSelectionCollision());
    results.add(_benchmarkBlockCreation());

    return results;
  }

  static BenchmarkResult _benchmarkSerialization() {
    final blocks = List.generate(500, (i) => MarkdownBlock(
      type: i % 3 == 0 ? BlockType.heading2 : (i % 3 == 1 ? BlockType.unorderedList : BlockType.paragraph),
      content: 'This is test block line number $i representing benchmark serialization content.',
    ));

    final stopwatch = Stopwatch()..start();
    final serialized = BlockParser.serialize(blocks);
    stopwatch.stop();

    // Clean up allocated controllers/focusnodes
    for (var b in blocks) {
      b.dispose();
    }

    final duration = stopwatch.elapsedMicroseconds.toDouble();
    final passed = duration <= 1500; // Standard: 1.5ms for 500 blocks

    return BenchmarkResult(
      testName: 'Markdown Serialization (500 Blocks)',
      durationMicroseconds: duration,
      status: passed ? 'Optimal (Bare-Metal)' : 'Suboptimal',
      standard: '< 1.5 ms',
    );
  }

  static BenchmarkResult _benchmarkParsing() {
    final buffer = StringBuffer();
    for (int i = 0; i < 500; i++) {
      if (i % 3 == 0) {
        buffer.writeln('## Heading Level 2 for block $i');
      } else if (i % 3 == 1) {
        buffer.writeln('- Bullet list item number $i');
      } else {
        buffer.writeln('Standard body paragraph content block for index $i.');
      }
    }
    final mdString = buffer.toString();

    final stopwatch = Stopwatch()..start();
    final parsed = BlockParser.parse(mdString);
    stopwatch.stop();

    for (var b in parsed) {
      b.dispose();
    }

    final duration = stopwatch.elapsedMicroseconds.toDouble();
    final passed = duration <= 3000; // Standard: 3ms for 500 blocks

    return BenchmarkResult(
      testName: 'Markdown Parsing (500 Blocks)',
      durationMicroseconds: duration,
      status: passed ? 'Optimal (Bare-Metal)' : 'Suboptimal',
      standard: '< 3.0 ms',
    );
  }

  static BenchmarkResult _benchmarkSelectionCollision() {
    // Generate 500 mock boxes/positions
    final rects = List.generate(500, (i) => Rect.fromLTWH(100.0, i * 40.0, 500.0, 35.0));
    final targetRect = const Rect.fromLTWH(100.0, 200.0, 500.0, 400.0);

    final stopwatch = Stopwatch()..start();
    int overlapsCount = 0;
    for (var r in rects) {
      if (targetRect.overlaps(r)) {
        overlapsCount++;
      }
    }
    stopwatch.stop();

    final duration = stopwatch.elapsedMicroseconds.toDouble();
    final passed = duration <= 100; // Standard: 0.1ms for 500 overlap checks

    return BenchmarkResult(
      testName: 'Selection Box Overlap (500 Checks)',
      durationMicroseconds: duration,
      status: passed ? 'Optimal (Bare-Metal)' : 'Suboptimal',
      standard: '< 0.1 ms',
    );
  }

  static BenchmarkResult _benchmarkBlockCreation() {
    final controller = BlockEditorController();
    controller.loadMarkdown('Initial block text.');

    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      controller.splitBlock(0, 'Split content $i');
    }
    stopwatch.stop();

    final duration = stopwatch.elapsedMicroseconds.toDouble();
    controller.dispose();

    final passed = duration <= 5000; // Standard: 5ms for 100 insertions (50us per insertion)

    return BenchmarkResult(
      testName: 'Block Creation/Insertions (100 Ops)',
      durationMicroseconds: duration,
      status: passed ? 'Optimal (Bare-Metal)' : 'Suboptimal',
      standard: '< 5.0 ms',
    );
  }
}
