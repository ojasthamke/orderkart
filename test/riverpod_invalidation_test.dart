import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

int buildCountA = 0;
int buildCountB = 0;

final testFamily = StateNotifierProvider.family<TestNotifier, int, String>((ref, id) {
  return TestNotifier(id);
});

class TestNotifier extends StateNotifier<int> {
  final String id;
  TestNotifier(this.id) : super(0) {
    if (id == 'A') buildCountA++;
    if (id == 'B') buildCountB++;
  }

  void increment() => state++;
}

void main() {
  test('Test if ref.invalidate(family) invalidates active family members', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Read both family members
    container.read(testFamily('A'));
    container.read(testFamily('B'));

    expect(buildCountA, equals(1));
    expect(buildCountB, equals(1));

    // Invalidate the family without arguments
    container.invalidate(testFamily);

    // Read again
    container.read(testFamily('A'));
    container.read(testFamily('B'));

    print('buildCountA after invalidate(testFamily): $buildCountA');
    print('buildCountB after invalidate(testFamily): $buildCountB');
    expect(buildCountA, equals(2));
    expect(buildCountB, equals(2));
  });
}
