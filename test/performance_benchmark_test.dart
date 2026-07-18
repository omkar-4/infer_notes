import 'package:flutter_test/flutter_test.dart';
import 'package:infer_notes/features/benchmarks/benchmark_engine.dart';

void main() {
  testWidgets('Run exhaustive performance benchmarks', (tester) async {
    print('======================================================');
    print('      RUNNING BARE-METAL PERFORMANCE BENCHMARKS      ');
    print('======================================================');

    final results = BenchmarkEngine.runAll();

    for (var res in results) {
      final durationStr = res.durationMicroseconds >= 1000
          ? '${(res.durationMicroseconds / 1000).toStringAsFixed(3)} ms'
          : '${res.durationMicroseconds.toStringAsFixed(0)} µs';
      print('${res.testName.padRight(40)} : $durationStr (${res.status}) [Standard: ${res.standard}]');
    }
    print('======================================================');
  });
}
