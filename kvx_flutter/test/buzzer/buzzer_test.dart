import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/data/datasources/binblog_device_datasource.dart';
import 'package:kvx_flutter/data/models/buzzer_detail_dto.dart';
import 'package:kvx_flutter/data/repositories/binblog_buzzer_repository.dart';
import 'package:kvx_flutter/domain/entities/buzzer_detail.dart';
import 'package:kvx_flutter/domain/repositories/buzzer_repository.dart';
import 'package:kvx_flutter/application/usecases/buzzer_usecases.dart';
import 'package:kvx_flutter/presentation/providers/buzzer_provider.dart';

class FakeBuzzerRepository implements BuzzerRepository {
  final pending = <Completer<BuzzerDetail>>[];
  bool deferLoads = false;
  BuzzerFailure? testFailure;
  int posts = 0;
  @override
  Future<BuzzerDetail> load(String id) {
    if (deferLoads) {
      final completer = Completer<BuzzerDetail>();
      pending.add(completer);
      return completer.future;
    }
    return Future.value(BuzzerDetailDto.fromDetailJson(detailResponse()));
  }

  @override
  Future<List<BuzzerSource>> loadLinkedPirs(String id) async => [];
  @override
  Future<List<BuzzerMotionEvent>> loadHistory(String id) async => [];
  @override
  Future<BuzzerTestReceipt> test(String id) async {
    posts++;
    if (testFailure case final error?) throw error;
    return const BuzzerTestReceipt(message: 'Command sent to MQTT broker');
  }
}

Map<String, dynamic> detailResponse() => {
  'status': 'success',
  'buzzer': {
    'id': 42,
    'name': 'Hall Buzzer',
    'chip_id': 'ESP32_BUZZER_02',
    'device_type': 'buzzer',
    'online': true,
    'last_seen': '2026-09-19T10:30:00+07:00',
    'linked_pir_count': 1,
    'last_triggered_at': '2026-09-19T10:29:00+07:00',
  },
};

Map<String, dynamic> linkedPirsResponse() => {
  'status': 'success',
  'linked_pirs': [
    {
      'id': 7,
      'name': 'Hall PIR',
      'chip_id': 'ESP32_PIR_01',
      'relay_index': 0,
      'longlast': 1000,
    },
  ],
};

Map<String, dynamic> historyResponse() => {
  'status': 'success',
  'events': [
    {
      'id': 123,
      'event_type': 'motion_detected',
      'occurred_at': '2026-09-19T10:29:00+07:00',
      'pir': {'id': 7, 'name': 'Hall PIR', 'chip_id': 'ESP32_PIR_01'},
      'relay_index': 0,
      'longlast': 1000,
    },
  ],
};

void main() {
  test(
    'null timestamps and empty lists are valid; malformed non-null timestamps fail',
    () {
      final valid = detailResponse()
        ..['buzzer'] = {
          ...detailResponse()['buzzer'] as Map<String, dynamic>,
          'last_seen': null,
          'last_triggered_at': null,
        };
      final detail = BuzzerDetailDto.fromDetailJson(valid);
      expect(detail.lastSeen, isNull);
      expect(detail.lastTriggeredAt, isNull);
      expect(
        BuzzerDetailDto.sourcesFromJson({
          'status': 'success',
          'linked_pirs': [],
        }),
        isEmpty,
      );
      expect(
        BuzzerDetailDto.eventsFromJson({'status': 'success', 'events': []}),
        isEmpty,
      );
      for (final field in ['last_seen', 'last_triggered_at']) {
        final invalid = detailResponse()
          ..['buzzer'] = {
            ...detailResponse()['buzzer'] as Map<String, dynamic>,
            field: 'bad',
          };
        expect(
          () => BuzzerDetailDto.fromDetailJson(invalid),
          throwsA(isA<BuzzerFailure>()),
        );
      }
    },
  );

  test(
    'successful test starts cooldown and reload only uses GET operations',
    () async {
      final repo = FakeBuzzerRepository();
      final model = BuzzerProvider(
        deviceId: '42',
        useCases: BuzzerUseCases(repo),
      );
      addTearDown(model.dispose);
      await model.load();
      await model.test();
      expect(model.cooldownSeconds, greaterThan(0));
      expect(repo.posts, 1);
      await model.load();
      expect(repo.posts, 1);
    },
  );

  test('server 429 updates local cooldown', () async {
    final repo = FakeBuzzerRepository()
      ..testFailure = const BuzzerFailure(
        BuzzerFailureKind.cooldown,
        retryAfterSeconds: 8,
      );
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repo),
    );
    addTearDown(model.dispose);
    await model.load();
    await model.test();
    expect(model.cooldownSeconds, greaterThanOrEqualTo(7));
  });

  test(
    'disposed and stale loads cannot notify or replace newer data',
    () async {
      final repo = FakeBuzzerRepository()..deferLoads = true;
      final model = BuzzerProvider(
        deviceId: '42',
        useCases: BuzzerUseCases(repo),
      );
      var notifications = 0;
      model.addListener(() => notifications++);
      final old = model.load();
      final newer = model.load();
      repo.pending[1].complete(
        BuzzerDetailDto.fromDetailJson(detailResponse()),
      );
      await newer;
      final count = notifications;
      repo.pending[0].complete(
        BuzzerDetailDto.fromDetailJson(
          detailResponse()
            ..['buzzer'] = {
              ...detailResponse()['buzzer'] as Map<String, dynamic>,
              'name': 'stale',
            },
        ),
      );
      await old;
      expect(model.detail?.name, 'Hall Buzzer');
      expect(notifications, count);
      repo.deferLoads = true;
      final pending = model.load();
      final disposedCount = notifications;
      model.dispose();
      repo.pending[2].complete(
        BuzzerDetailDto.fromDetailJson(detailResponse()),
      );
      await pending;
      expect(notifications, disposedCount);
    },
  );

  test('401, 422 and 503 map to their failure kinds', () async {
    for (final entry in {
      401: BuzzerFailureKind.authentication,
      422: BuzzerFailureKind.configuration,
      503: BuzzerFailureKind.command,
    }.entries) {
      final source = BinblogDeviceDataSource(
        username: 'fixture',
        password: 'fixture',
        client: MockClient((request) async {
          if (request.url.path == '/api/login') {
            return http.Response('{"token":"token"}', 200);
          }
          return http.Response('{"status":"error"}', entry.key);
        }),
      );
      final repo = BinblogBuzzerRepository(source);
      await expectLater(
        repo.test('42'),
        throwsA(
          isA<BuzzerFailure>().having((e) => e.kind, 'kind', entry.value),
        ),
      );
      source.close();
    }
  });
  test('DTOs map the four backend #101 response schemas', () {
    final detail = BuzzerDetailDto.fromDetailJson(detailResponse());
    final pirs = BuzzerDetailDto.sourcesFromJson(linkedPirsResponse());
    final events = BuzzerDetailDto.eventsFromJson(historyResponse());
    expect(detail.id, '42');
    expect(detail.linkedPirCount, 1);
    expect(detail.lastTriggeredAt, isNotNull);
    expect(pirs.single.id, '7');
    expect(pirs.single.longlast, 1000);
    expect(events.single.pirId, '7');
    expect(events.single.longlast, 1000);
  });

  test('invalid detail and history data are rejected', () {
    expect(
      () => BuzzerDetailDto.fromDetailJson({
        'status': 'success',
        'buzzer': {'device_type': 'pir'},
      }),
      throwsA(isA<BuzzerFailure>()),
    );
    final invalid = historyResponse()
      ..['events'] = List.generate(21, (_) => historyResponse()['events'][0]);
    expect(
      () => BuzzerDetailDto.eventsFromJson(invalid),
      throwsA(isA<BuzzerFailure>()),
    );
  });

  test('repository uses device-scoped paths and Bearer authentication', () async {
    final requests = <http.Request>[];
    final source = BinblogDeviceDataSource(
      username: 'fixture',
      password: 'fixture',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/login') {
          return http.Response('{"token":"fixture-token"}', 200);
        }
        expect(request.headers['Authorization'], 'Bearer fixture-token');
        expect(request.headers['Accept'], 'application/json');
        switch (request.url.path) {
          case '/api/devices/42/buzzer':
            return http.Response(jsonEncode(detailResponse()), 200);
          case '/api/devices/42/buzzer/linked_pirs':
            return http.Response(jsonEncode(linkedPirsResponse()), 200);
          case '/api/devices/42/buzzer/history':
            return http.Response(jsonEncode(historyResponse()), 200);
          case '/api/devices/42/buzzer/test':
            return http.Response(
              '{"status":"success","message":"Command sent to MQTT broker","relay_index":0,"longlast":1000}',
              200,
            );
          default:
            return http.Response('{}', 404);
        }
      }),
    );
    addTearDown(source.close);
    final repository = BinblogBuzzerRepository(source);
    await repository.load('42');
    await repository.loadLinkedPirs('42');
    await repository.loadHistory('42');
    final receipt = await repository.test('42');
    expect(receipt.message, 'Command sent to MQTT broker');
    expect(
      requests.map((request) => request.url.path),
      containsAll([
        '/api/devices/42/buzzer',
        '/api/devices/42/buzzer/linked_pirs',
        '/api/devices/42/buzzer/history',
        '/api/devices/42/buzzer/test',
      ]),
    );
  });

  test('429 maps to server cooldown and 404 maps to unavailable', () async {
    final source = BinblogDeviceDataSource(
      username: 'fixture',
      password: 'fixture',
      client: MockClient((request) async {
        if (request.url.path == '/api/login') {
          return http.Response('{"token":"token"}', 200);
        }
        if (request.url.path.endsWith('/test')) {
          return http.Response(
            '{"status":"error"}',
            429,
            headers: {'retry-after': '5'},
          );
        }
        return http.Response('{"status":"error"}', 404);
      }),
    );
    addTearDown(source.close);
    final repository = BinblogBuzzerRepository(source);
    await expectLater(
      repository.load('42'),
      throwsA(
        isA<BuzzerFailure>().having(
          (e) => e.kind,
          'kind',
          BuzzerFailureKind.unavailable,
        ),
      ),
    );
    await expectLater(
      repository.test('42'),
      throwsA(
        isA<BuzzerFailure>().having((e) => e.retryAfterSeconds, 'retry', 5),
      ),
    );
  });
}
