import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/domain/entities/relay_channel.dart';

void main() {
  group('RelayChannel', () {
    test('creates instance with required fields', () {
      const channel = RelayChannel(
        index: 0,
        isOn: true,
      );

      expect(channel.index, 0);
      expect(channel.isOn, true);
      expect(channel.label, null);
    });

    test('creates instance with optional label', () {
      const channel = RelayChannel(
        index: 1,
        isOn: false,
        label: 'Máy bơm',
      );

      expect(channel.index, 1);
      expect(channel.isOn, false);
      expect(channel.label, 'Máy bơm');
    });

    test('copyWith creates new instance with updated fields', () {
      const original = RelayChannel(
        index: 0,
        isOn: false,
        label: 'Old Label',
      );

      final updated = original.copyWith(isOn: true, label: 'New Label');

      expect(updated.index, 0);
      expect(updated.isOn, true);
      expect(updated.label, 'New Label');
      expect(original.isOn, false); // original unchanged
    });

    test('copyWith preserves fields when not provided', () {
      const original = RelayChannel(
        index: 2,
        isOn: true,
        label: 'Test',
      );

      final updated = original.copyWith(isOn: false);

      expect(updated.index, 2);
      expect(updated.isOn, false);
      expect(updated.label, 'Test');
    });

    test('equality based on index', () {
      const channel1 = RelayChannel(index: 0, isOn: true);
      const channel2 = RelayChannel(index: 0, isOn: false);
      const channel3 = RelayChannel(index: 1, isOn: true);

      expect(channel1, equals(channel2)); // same index
      expect(channel1, isNot(equals(channel3))); // different index
    });

    test('hashCode based on index', () {
      const channel1 = RelayChannel(index: 0, isOn: true);
      const channel2 = RelayChannel(index: 0, isOn: false);
      const channel3 = RelayChannel(index: 1, isOn: true);

      expect(channel1.hashCode, equals(channel2.hashCode));
      expect(channel1.hashCode, isNot(equals(channel3.hashCode)));
    });
  });
}
