import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:kvx_flutter/application/usecases/buzzer_usecases.dart';
import 'package:kvx_flutter/data/datasources/binblog_device_datasource.dart';
import 'package:kvx_flutter/data/models/binblog_device_dto.dart';
import 'package:kvx_flutter/data/models/buzzer_detail_dto.dart';
import 'package:kvx_flutter/data/repositories/binblog_buzzer_repository.dart';
import 'package:kvx_flutter/domain/entities/buzzer_detail.dart';
import 'package:kvx_flutter/domain/entities/device.dart';
import 'package:kvx_flutter/domain/repositories/buzzer_repository.dart';
import 'package:kvx_flutter/presentation/providers/buzzer_provider.dart';
import 'package:kvx_flutter/presentation/screens/buzzer_detail_screen.dart';
import 'package:kvx_flutter/presentation/screens/device_detail_screen.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(
          File('../kvxTests/Fixtures/buzzer-detail.json').readAsStringSync(),
        )
        as Map<String, dynamic>;
BuzzerDetail detail({int? duration = 1000, String name = 'Buzzer'}) =>
    BuzzerDetailDto.fromJson(
      fixture()
        ..['test_duration_ms'] = duration
        ..['name'] = name,
    );

class FakeBuzzer extends BuzzerRepository {
  BuzzerDetail value = detail();
  Object? loadError;
  Object? sendError;
  int loads = 0;
  final commands = <BuzzerCommand>[];
  final pending = <Completer<BuzzerDetail>>[];
  bool suspendLoad = false;
  Completer<BuzzerCommandReceipt>? pendingSend;
  @override
  Future<BuzzerDetail> load(String deviceId) {
    loads++;
    if (suspendLoad) {
      final request = Completer<BuzzerDetail>();
      pending.add(request);
      return request.future;
    }
    return loadError == null ? Future.value(value) : Future.error(loadError!);
  }

  @override
  Future<BuzzerCommandReceipt> send(String deviceId, BuzzerCommand command) {
    expect(deviceId, '59');
    commands.add(command);
    if (pendingSend != null) return pendingSend!.future;
    return sendError == null
        ? Future.value(
            BuzzerCommandReceipt(
              cooldownSeconds: command == BuzzerCommand.test ? 3 : 0,
            ),
          )
        : Future.error(sendError!);
  }
}

void main() {
  test(
    'lost device access clears cached snapshot and blocks commands',
    () async {
      final repo = FakeBuzzer();
      final model = BuzzerProvider(
        deviceId: '59',
        useCases: BuzzerUseCases(repo),
      );
      addTearDown(model.dispose);
      await model.load();
      repo.loadError = const BuzzerFailure(BuzzerFailureKind.unavailable);
      await model.load();
      await model.send(BuzzerCommand.restart);
      expect(model.detail, null);
      expect(repo.commands, isEmpty);
    },
  );
  test('shared fixture maps identity, units and UTC+7 dates', () {
    final value = BuzzerDetailDto.fromJson(fixture());
    expect(value.id, '59');
    expect(value.chipId, 'fixture_buzzer');
    expect(value.sources.single.relayIndex, 0);
    expect(value.events.single.durationMs, 1000);
    expect(
      formatBuzzerDate(value.events.single.occurredAt),
      '17/09/2026 01:30:00',
    );
    expect(formatBuzzerDate(value.lastSeen), '17/09/2026 15:00:00');
  });

  test(
    'missing optional fields work; malformed source, date, and event identity fail',
    () {
      final json = fixture()
        ..remove('last_seen')
        ..remove('build_version')
        ..remove('test_duration_ms')
        ..['events'] = []
        ..['sources'] = [];
      final value = BuzzerDetailDto.fromJson(json);
      expect(value.canTest, false);
      expect(value.lastSeen, null);
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (v) => v['sources'] = null,
        (v) => v['events'][0]['occurred_at'] = 'invalid',
        (v) => v['events'][0]['source_id'] = 'unrelated',
        (v) => v['sources'][0]['relay_index'] = -1,
        (v) =>
            v['events'].add(Map<String, dynamic>.from(v['events'][0] as Map)),
      ]) {
        final bad = fixture();
        mutate(bad);
        expect(
          () => BuzzerDetailDto.fromJson(bad),
          throwsA(isA<BuzzerFailure>()),
        );
      }
    },
  );

  test('list recognizes buzzer and preserves its chip identity', () {
    final device = BinblogDeviceDto.fromJson({
      'id': 59,
      'name': 'Buzzer',
      'device_type': 'buzzer',
      'chip_id': 'fixture_buzzer',
    }).toDomain();
    expect(device.type, DeviceType.buzzer);
    expect(
      device.copyWith(status: DeviceStatus.online).chipId,
      'fixture_buzzer',
    );
  });

  test('use case validates duration boundaries before sending', () async {
    final repo = FakeBuzzer();
    final useCases = BuzzerUseCases(repo);
    for (final duration in [100, 10000]) {
      await useCases.execute(detail(duration: duration), BuzzerCommand.test);
    }
    for (final duration in [null, 99, 10001]) {
      expect(
        () => useCases.execute(detail(duration: duration), BuzzerCommand.test),
        throwsA(isA<BuzzerFailure>()),
      );
    }
    expect(repo.commands.length, 2);
  });

  test(
    'refresh sends once then reads and read retry never repeats mutation',
    () async {
      final repo = FakeBuzzer();
      final model = BuzzerProvider(
        deviceId: '59',
        useCases: BuzzerUseCases(repo),
      );
      addTearDown(model.dispose);
      await model.load();
      repo.loadError = const BuzzerFailure(BuzzerFailureKind.connection);
      await model.send(BuzzerCommand.refresh);
      expect(repo.commands, [BuzzerCommand.refresh]);
      expect(model.notice, contains('chưa có xác nhận'));
      expect(model.errorMessage, isNotNull);
      expect(model.detail, isNotNull);
      expect(model.isBusy, false);
      repo.loadError = null;
      await model.load();
      expect(repo.commands.length, 1);
      expect(model.errorMessage, null);
    },
  );

  test(
    'command failure reports no success and never retries automatically',
    () async {
      final repo = FakeBuzzer()
        ..sendError = const BuzzerFailure(BuzzerFailureKind.command);
      final model = BuzzerProvider(
        deviceId: '59',
        useCases: BuzzerUseCases(repo),
      );
      addTearDown(model.dispose);
      await model.load();
      await model.send(BuzzerCommand.restart);
      expect(repo.commands, [BuzzerCommand.restart]);
      expect(model.notice, null);
      expect(model.isBusy, false);
      expect(model.errorMessage, isNotNull);
    },
  );

  test('401 clears prior data and commands until login succeeds', () async {
    final repo = FakeBuzzer();
    final model = BuzzerProvider(
      deviceId: '59',
      useCases: BuzzerUseCases(repo),
    );
    addTearDown(model.dispose);
    await model.load();
    repo.loadError = const BuzzerFailure(BuzzerFailureKind.authentication);
    await model.load();
    await model.send(BuzzerCommand.test);
    expect(model.needsLogin, true);
    expect(model.detail, null);
    expect(repo.commands, isEmpty);
    repo.loadError = null;
    await model.load();
    expect(model.needsLogin, false);
  });

  test(
    'latest load wins and disposed provider ignores pending results',
    () async {
      final repo = FakeBuzzer()..suspendLoad = true;
      final model = BuzzerProvider(
        deviceId: '59',
        useCases: BuzzerUseCases(repo),
      );
      final first = model.load();
      final second = model.load();
      repo.pending[1].complete(detail(name: 'new'));
      await second;
      repo.pending[0].complete(detail(name: 'old'));
      await first;
      expect(model.detail!.name, 'new');
      final third = model.load();
      model.dispose();
      repo.pending[2].complete(detail(name: 'after dispose'));
      await third;
      expect(model.detail!.name, 'new');
    },
  );

  test(
    'pending mutation blocks duplicate taps and concurrent reloads',
    () async {
      final repo = FakeBuzzer()
        ..pendingSend = Completer<BuzzerCommandReceipt>();
      final model = BuzzerProvider(
        deviceId: '59',
        useCases: BuzzerUseCases(repo),
      );
      addTearDown(model.dispose);
      await model.load();
      final first = model.send(BuzzerCommand.restart);
      await model.send(BuzzerCommand.restart);
      await model.load();
      expect(repo.commands.length, 1);
      expect(repo.loads, 1);
      repo.pendingSend!.complete(const BuzzerCommandReceipt());
      await first;
      expect(model.isBusy, false);
    },
  );

  test(
    'successful test cooldown and server cooldown prevent repeated commands',
    () async {
      final repo = FakeBuzzer();
      var now = DateTime.utc(2026);
      final model = BuzzerProvider(
        deviceId: '59',
        useCases: BuzzerUseCases(repo),
        now: () => now,
      );
      addTearDown(model.dispose);
      await model.load();
      await model.send(BuzzerCommand.test);
      await model.send(BuzzerCommand.test);
      expect(repo.commands.length, 1);
      now = now.add(const Duration(seconds: 3));
      repo.sendError = const BuzzerFailure(
        BuzzerFailureKind.cooldown,
        retryAfterSeconds: 5,
      );
      await model.send(BuzzerCommand.test);
      expect(model.cooldownSeconds, 5);
      expect(model.notice, null);
    },
  );

  test(
    'HTTP sends Bearer, uses database ID, maps cooldown and reauthenticates after 401',
    () async {
      var logins = 0;
      var gets = 0;
      var posts = 0;
      final source = BinblogDeviceDataSource(
        username: 'fixture',
        password: 'fixture',
        client: MockClient((request) async {
          if (request.url.path == '/api/login') {
            logins++;
            return http.Response('{"token":"fixture-token"}', 200);
          }
          expect(request.headers['Authorization'], 'Bearer fixture-token');
          expect(request.headers['Accept'], 'application/json');
          if (request.method == 'GET') {
            expect(request.url.path, '/api/buzzers/59');
            gets++;
            return gets == 1
                ? http.Response('{}', 401)
                : http.Response(
                    jsonEncode(fixture()),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
          }
          posts++;
          expect(request.url.path, '/api/buzzers/59/test');
          expect(request.body, '{}');
          return http.Response(
            '{"error":"cooldown"}',
            429,
            headers: {'retry-after': '5'},
          );
        }),
      );
      addTearDown(source.close);
      final repo = BinblogBuzzerRepository(source);
      await expectLater(
        repo.load('59'),
        throwsA(
          isA<BuzzerFailure>().having(
            (e) => e.kind,
            'kind',
            BuzzerFailureKind.authentication,
          ),
        ),
      );
      await repo.load('59');
      expect(logins, 2);
      await expectLater(
        repo.send('59', BuzzerCommand.test),
        throwsA(
          isA<BuzzerFailure>().having((e) => e.retryAfterSeconds, 'retry', 5),
        ),
      );
      expect(posts, 1);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'native Flutter routing, layout and cancel/confirm in $brightness',
      (tester) async {
        final repo = FakeBuzzer();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          Provider<BuzzerUseCases>.value(
            value: BuzzerUseCases(repo),
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.6),
                  platformBrightness: brightness,
                ),
                child: child!,
              ),
              home: const DeviceDetailScreen(
                device: Device(
                  id: '59',
                  name: 'Buzzer',
                  chipId: 'fixture_buzzer',
                  type: DeviceType.buzzer,
                  status: DeviceStatus.online,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bật/Tắt thiết bị'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Test Buzzer'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Buzzer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(repo.commands, isEmpty);
        await tester.tap(find.text('Test Buzzer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(repo.commands, [BuzzerCommand.test]);
        await tester.scrollUntilVisible(
          find.text('Thay đổi WiFi'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thay đổi WiFi'));
        await tester.pumpAndSettle();
        expect(find.textContaining('xóa WiFi cũ'), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(repo.commands.length, 1);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'shared Device data remains visible when Buzzer API is unavailable',
    (tester) async {
      final repo = FakeBuzzer()
        ..loadError = const BuzzerFailure(BuzzerFailureKind.unavailable);
      await tester.pumpWidget(
        MaterialApp(
          home: BuzzerDetailScreen(
            device: const Device(
              id: '59',
              name: 'C Oanh- Loa buzzer',
              chipId: 'shared_device_chip',
              type: DeviceType.buzzer,
              status: DeviceStatus.busy,
            ),
            useCases: BuzzerUseCases(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('C Oanh- Loa buzzer'), findsNWidgets(2));
      expect(find.text('shared_device_chip'), findsOneWidget);
      expect(find.text('● Busy'), findsOneWidget);
      expect(find.text('Dữ liệu mở rộng và điều khiển Buzzer'), findsOneWidget);
      expect(find.text('Test Buzzer'), findsNothing);
      expect(
        find.text('Chưa có lịch sử lệnh từ PIR cho Buzzer này.'),
        findsNothing,
      );
      expect(repo.commands, isEmpty);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('empty offline screen, load failure and retry', (tester) async {
    final repo = FakeBuzzer()
      ..loadError = const BuzzerFailure(BuzzerFailureKind.connection);
    repo.value = BuzzerDetailDto.fromJson(
      fixture()
        ..['sources'] = []
        ..['events'] = []
        ..['online'] = false
        ..['test_duration_ms'] = null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BuzzerDetailScreen(
          device: const Device(
            id: '59',
            name: 'Buzzer',
            type: DeviceType.buzzer,
            status: DeviceStatus.offline,
          ),
          useCases: BuzzerUseCases(repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tải lại dữ liệu'), findsOneWidget);
    repo.loadError = null;
    await tester.tap(find.text('Tải lại dữ liệu'));
    await tester.pumpAndSettle();
    expect(find.text('○ Offline'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
  });
}
