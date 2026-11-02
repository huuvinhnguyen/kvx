import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/application/usecases/switch_use_cases.dart';
import 'package:kvx_flutter/data/models/switch_dto.dart';
import 'package:kvx_flutter/data/repositories/binblog_switch_repository.dart';
import 'package:kvx_flutter/domain/entities/switch_detail.dart';
import 'package:kvx_flutter/domain/repositories/switch_repository.dart';
import 'package:kvx_flutter/presentation/providers/switch_provider.dart';
import 'package:kvx_flutter/presentation/screens/switch_detail_screen.dart';
import '../support/auth_fixture.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/switch_api/$name.json').readAsStringSync())
        as Map<String, dynamic>;

class FakeSwitch implements SwitchRepository {
  bool failRead = false;
  bool unknown = false;
  Completer<void>? pending;
  Completer<SwitchDetail>? pendingRead;
  int posts = 0;
  bool multiRelay = false;
  final calls = <String>[];
  @override
  Future<SwitchDetail> detail(String id) async {
    if (pendingRead != null) return pendingRead!.future;
    if (failRead) throw const SwitchFailure(SwitchFailureKind.connection);
    final j = fixture('detail');
    j['switch']['id'] = id;
    if (multiRelay) {
      j['switch']['relays'].add({
        'index': 1,
        'switch_value': 0,
        'duration_ms': null,
        'reminders_active': null,
      });
    }
    return SwitchDto.detail(j);
  }

  @override
  Future<SwitchReminderPage> reminders(
    String id,
    int relay, {
    String? afterId,
  }) async {
    calls.add('reminders:$relay:$afterId');
    return const SwitchReminderPage([], null);
  }

  @override
  Future<SwitchStatistics> statistics(String id, int relay) async =>
      SwitchDto.statistics(fixture('statistics'));
  Future<void> command(String name) async {
    posts++;
    calls.add(name);
    if (pending != null) await pending!.future;
    if (unknown) throw const SwitchFailure(SwitchFailureKind.uncertain);
  }

  @override
  Future<void> state(String id, int relay, int value) =>
      command('state:$id:$relay:$value');
  @override
  Future<void> pulse(String id, int relay, int ms) =>
      command('pulse:$id:$relay:$ms');
  @override
  Future<void> refresh(String id) => command('refresh:$id');
}

void main() {
  test('duration positive whole units, upper bound and overflow', () {
    expect(switchDurationMs('1', minutes: false), 1000);
    expect(switchDurationMs('1440', minutes: true), 86400000);
    for (final text in [
      '',
      '0',
      '-1',
      '1.5',
      '86401',
      '99999999999999999999999999999999',
    ]) {
      expect(switchDurationMs(text, minutes: false), null);
    }
  });
  test('shared detail preserves unknown state, rejects missing/malformed', () {
    final j = fixture('detail');
    expect(SwitchDto.detail(j).relays.single.switchValue, null);
    j['switch']['relays'][0]['switch_value'] = false;
    expect(() => SwitchDto.detail(j), throwsA(isA<SwitchFailure>()));
    j['switch']['relays'][0].remove('switch_value');
    expect(() => SwitchDto.detail(j), throwsA(isA<SwitchFailure>()));
  });
  test('empty relays valid, malformed relay array rejected', () {
    final j = fixture('detail');
    j['switch']['relays'] = [];
    expect(SwitchDto.detail(j).relays, isEmpty);
    j['switch']['relays'] = [
      {'index': 1},
    ];
    expect(() => SwitchDto.detail(j), throwsA(isA<SwitchFailure>()));
  });
  test(
    'reminder identity, cursor progress, scope and invalid legacy values',
    () {
      final j = fixture('reminders');
      expect(
        SwitchDto.reminders(j, '1', 0, null).reminders.single.repeatType,
        'once',
      );
      j['reminders'][0]['configuration_valid'] = false;
      j['reminders'][0]['duration_ms'] = null;
      j['reminders'][0]['start_time'] = null;
      j['reminders'][0]['repeat_type'] = 'unsupported';
      expect(
        SwitchDto.reminders(
          j,
          '1',
          0,
          null,
        ).reminders.single.configurationValid,
        false,
      );
      expect(
        () => SwitchDto.reminders(j, '2', 0, null),
        throwsA(isA<SwitchFailure>()),
      );
      j['next_after_id'] = '2';
      expect(
        () => SwitchDto.reminders(j, '1', 0, null),
        throwsA(isA<SwitchFailure>()),
      );
    },
  );
  test(
    'statistics count logs only and reject fabricated runtime or missing days',
    () {
      final j = fixture('statistics');
      expect(SwitchDto.statistics(j).totalRecords, 0);
      j['physical_runtime_seconds'] = 10;
      expect(() => SwitchDto.statistics(j), throwsA(isA<SwitchFailure>()));
      j['physical_runtime_seconds'] = null;
      j['days'] = [];
      expect(() => SwitchDto.statistics(j), throwsA(isA<SwitchFailure>()));
    },
  );
  test(
    'statistics date arithmetic uses +07 calendar, independent of phone DST',
    () {
      final j = fixture('statistics');
      for (final start in ['2026-03-06', '2026-10-30']) {
        final from = DateTime.parse('${start}T00:00:00Z');
        j['from'] = start;
        j['to'] = from
            .add(const Duration(days: 6))
            .toIso8601String()
            .substring(0, 10);
        j['days'] = List.generate(
          7,
          (i) => {
            'date': from
                .add(Duration(days: i))
                .toIso8601String()
                .substring(0, 10),
            'count': 0,
          },
        );
        expect(SwitchDto.statistics(j).days.length, 7);
      }
    },
  );
  test(
    'authenticated paths/methods/bodies and bodyless refresh with no retries',
    () async {
      final calls = <http.Request>[];
      final repo = BinblogSwitchRepository(
        authenticatedFixture(
          client: MockClient((r) async {
            calls.add(r);
            expect(r.headers['Authorization'], 'Bearer token');
            expect(r.headers['Accept'], 'application/json');
            final name = r.method == 'POST'
                ? 'command'
                : r.url.path.endsWith('reminders')
                ? 'reminders'
                : r.url.path.endsWith('statistics')
                ? 'statistics'
                : 'detail';
            final j = fixture(name);
            if (name == 'reminders') j['reminders'] = [];
            return http.Response(jsonEncode(j), 200);
          }),
        ),
      );
      await repo.detail('1');
      await repo.reminders('1', 0, afterId: '5');
      await repo.statistics('1', 0);
      await repo.state('1', 0, 1);
      await repo.state('1', 0, 0);
      await repo.pulse('1', 0, 60000);
      await repo.refresh('1');
      expect(calls.map((r) => r.method), [
        'GET',
        'GET',
        'GET',
        'POST',
        'POST',
        'POST',
        'POST',
      ]);
      expect(calls[1].url.queryParameters, {'limit': '100', 'after_id': '5'});
      expect(calls[3].url.path, '/api/switches/1/relays/0/state');
      expect(jsonDecode(calls[3].body), {'switch_value': 1});
      expect(jsonDecode(calls[5].body), {'duration_ms': 60000});
      expect(calls[6].url.path, '/api/switches/1/refresh');
      expect(calls[6].body, isEmpty);
      expect(calls.every((r) => !r.url.path.contains('/api/devices')), true);
    },
  );
  test(
    'mutation timeout/502/malformed success each uncertain and only one request',
    () async {
      for (final kind in ['network', '502', 'malformed']) {
        var count = 0;
        final repo = BinblogSwitchRepository(
          authenticatedFixture(
            client: MockClient((r) async {
              count++;
              if (kind == 'network') throw TimeoutException('synthetic');
              return http.Response(
                kind == 'malformed'
                    ? '{}'
                    : '{"code":"command_outcome_unknown","outcome":"unknown"}',
                kind == '502' ? 502 : 200,
              );
            }),
          ),
        );
        await expectLater(
          repo.state('1', 0, 1),
          throwsA(
            isA<SwitchFailure>().having(
              (e) => e.kind,
              'kind',
              SwitchFailureKind.uncertain,
            ),
          ),
        );
        expect(count, 1);
      }
    },
  );
  test('401/404/422/feature503 typed, validation never dispatches', () async {
    for (final code in [401, 404, 422, 503]) {
      final repo = BinblogSwitchRepository(
        authenticatedFixture(
          client: MockClient(
            (r) async => http.Response('{"code":"feature_unavailable"}', code),
          ),
        ),
      );
      await expectLater(repo.detail('1'), throwsA(isA<SwitchFailure>()));
    }
    var count = 0;
    final repo = BinblogSwitchRepository(
      authenticatedFixture(
        client: MockClient((r) async {
          count++;
          return http.Response('{}', 200);
        }),
      ),
    );
    expect(() => repo.state('chip_id', 0, 1), throwsA(isA<SwitchFailure>()));
    expect(() => repo.pulse('1', 0, 999), throwsA(isA<SwitchFailure>()));
    expect(count, 0);
  });
  test(
    'duplicate commands locked, no optimistic state, follow-up GET',
    () async {
      final repo = FakeSwitch();
      final p = SwitchProvider(deviceId: '1', useCases: SwitchUseCases(repo));
      await p.load();
      repo.pending = Completer<void>();
      final first = p.state(1);
      await p.state(0);
      await p.refreshDevice();
      expect(repo.posts, 1);
      expect(p.detail!.relays.single.switchValue, null);
      repo.pending!.complete();
      await first;
      expect(p.readReady, true);
      expect(p.notice, contains('chưa xác nhận'));
      expect(repo.posts, 1);
      p.dispose();
    },
  );
  test(
    'unknown persists across read; failed read blocks acknowledgement and new writes',
    () async {
      final repo = FakeSwitch()..unknown = true;
      final p = SwitchProvider(deviceId: '1', useCases: SwitchUseCases(repo));
      await p.load();
      await p.state(1);
      expect(p.uncertain, true);
      expect(p.canCommand, false);
      await p.state(1);
      expect(repo.posts, 1);
      repo.failRead = true;
      await p.load();
      p.acknowledgePhysicalCheck();
      expect(p.uncertain, true);
      repo.failRead = false;
      await p.load();
      expect(p.uncertain, true);
      p.acknowledgePhysicalCheck();
      expect(p.canCommand, true);
      p.dispose();
    },
  );
  test(
    'relay selection uses exact selected index and invalid duration sends nothing',
    () async {
      final repo = FakeSwitch()..multiRelay = true;
      final p = SwitchProvider(deviceId: '1', useCases: SwitchUseCases(repo));
      await p.load();
      await p.selectRelay(1);
      await p.state(0);
      expect(repo.calls, contains('state:1:1:0'));
      expect(repo.calls, contains('reminders:1:null'));
      await p.pulse(999);
      expect(repo.posts, 1);
      expect(p.errorMessage, contains('không hợp lệ'));
      p.dispose();
    },
  );
  test('disposed response ignored', () async {
    final repo = FakeSwitch()..pendingRead = Completer<SwitchDetail>();
    final p = SwitchProvider(deviceId: '1', useCases: SwitchUseCases(repo));
    final load = p.load();
    p.dispose();
    repo.pendingRead!.complete(SwitchDto.detail(fixture('detail')));
    await load;
    expect(p.detail, null);
  });
  test(
    'reopened screen shares pending/unknown command guard until explicit reconciliation',
    () async {
      final repo = FakeSwitch()
        ..unknown = true
        ..pending = Completer<void>();
      final cases = SwitchUseCases(repo);
      final first = SwitchProvider(deviceId: '1', useCases: cases);
      await first.load();
      final command = first.state(1);
      first.dispose();
      final reopened = SwitchProvider(deviceId: '1', useCases: cases);
      await reopened.load();
      expect(reopened.canCommand, false);
      reopened.acknowledgePhysicalCheck();
      await reopened.state(0);
      expect(repo.posts, 1);
      repo.pending!.complete();
      await command;
      expect(reopened.uncertain, true);
      await reopened.load();
      expect(reopened.canCommand, false);
      reopened.acknowledgePhysicalCheck();
      expect(reopened.canCommand, true);
      reopened.dispose();
    },
  );
  testWidgets(
    'unknown snapshot, explicit ON/OFF, read-only reminders and real log label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SwitchDetailScreen(
            deviceId: '1',
            useCases: SwitchUseCases(FakeSwitch()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái snapshot: Chưa xác định'), findsOneWidget);
      expect(find.text('BẬT'), findsOneWidget);
      expect(find.text('TẮT'), findsOneWidget);
      // The duration TextField also owns a Scrollable; target the page list.
      final pageScrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable && widget.axisDirection == AxisDirection.down,
        ),
      );
      expect(pageScrollable, findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Hẹn giờ — chỉ đọc'),
        200,
        scrollable: pageScrollable,
      );
      expect(find.text('Hẹn giờ — chỉ đọc'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Thống kê bản ghi log · UTC+07'),
        300,
        scrollable: pageScrollable,
      );
      expect(find.text('Thống kê bản ghi log · UTC+07'), findsOneWidget);
      expect(find.text('Thêm hẹn giờ'), findsNothing);
    },
  );
}
