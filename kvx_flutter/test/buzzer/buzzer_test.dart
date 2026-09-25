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
  int links = 0;
  int unlinks = 0;
  bool failAvailable = false;
  bool deferLink = false;
  Completer<void>? pendingLink;
  BuzzerFailure? linkFailure;
  BuzzerFailure? unlinkFailure;
  @override
  Future<List<AvailableBuzzerPir>> loadAvailablePirs(String id) async {
    if (failAvailable) throw const BuzzerFailure(BuzzerFailureKind.connection);
    return [
      const AvailableBuzzerPir(
        id: '7',
        name: 'Hall PIR',
        chipId: 'pir7',
        requiresConfirmation: false,
      ),
    ];
  }

  @override
  Future<void> link(String id, BuzzerLinkConfiguration configuration) async {
    links++;
    if (deferLink) {
      pendingLink = Completer<void>();
      await pendingLink!.future;
    }
    if (linkFailure case final error?) throw error;
  }

  @override
  Future<void> unlink(String id, String pirId) async {
    unlinks++;
    if (unlinkFailure case final error?) throw error;
  }

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

class BuzzerManagementTransportHarness {
  final requests = <http.Request>[];
  int postCalls = 0;
  int deleteCalls = 0;
  bool failPost = true;
  bool failDelete = true;
  late final BinblogDeviceDataSource source;
  late final BuzzerProvider model;

  BuzzerManagementTransportHarness() {
    source = BinblogDeviceDataSource(
      username: 'fixture',
      password: 'fixture',
      client: MockClient(_respond),
    );
    model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(BinblogBuzzerRepository(source)),
    );
  }

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    if (request.url.path == '/api/login') {
      return http.Response('{"token":"token"}', 200);
    }
    if (request.method == 'POST' && request.url.path.endsWith('/linked_pirs')) {
      postCalls++;
      if (failPost) throw http.ClientException('connection reset');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'linked_pir': {
            'id': body['pir_id'],
            'name': 'Hall PIR',
            'chip_id': 'ESP32_PIR_01',
            'relay_index': body['relay_index'],
            'longlast': body['longlast'],
          },
        }),
        200,
      );
    }
    if (request.method == 'DELETE' &&
        request.url.path.endsWith('/linked_pirs/7')) {
      deleteCalls++;
      if (failDelete) throw http.ClientException('connection reset');
      return http.Response('{"status":"success","pir_id":7}', 200);
    }
    if (request.method == 'GET') {
      if (request.url.path.endsWith('/available_pirs')) {
        return http.Response(
          '{"status":"success","available_pirs":[{"id":7,"name":"Hall PIR","chip_id":"ESP32_PIR_01","linked_buzzer":null,"requires_confirmation":false}]}',
          200,
        );
      }
      if (request.url.path.endsWith('/linked_pirs')) {
        return http.Response(jsonEncode(linkedPirsResponse()), 200);
      }
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode(historyResponse()), 200);
      }
      if (request.url.path.endsWith('/buzzer')) {
        return http.Response(jsonEncode(detailResponse()), 200);
      }
    }
    return http.Response('{}', 404);
  }

  void dispose() {
    model.dispose();
    source.close();
  }
}

void main() {
  test('mutation refresh failure blocks another write', () async {
    final repository = FakeBuzzerRepository();
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repository),
    );
    await model.load();
    await model.loadAvailable();
    repository.failAvailable = true;
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(repository.links, 1);
    expect(model.requiresRefresh, isTrue);
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(repository.links, 1);
    expect(repository.posts, 0);
    expect(model.errorMessage, contains('Đã cập nhật'));
    await model.load();
    expect(model.requiresRefresh, isTrue);
    expect(model.errorMessage, contains('Đã cập nhật'));
    repository.failAvailable = false;
    await model.load();
    expect(model.requiresRefresh, isFalse);
    expect(model.notice, contains('Đã cập nhật'));
    model.dispose();
  });

  test('uncertain link blocks writes until read refresh', () async {
    final repository = FakeBuzzerRepository()
      ..linkFailure = const BuzzerFailure(BuzzerFailureKind.uncertainMutation);
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repository),
    );
    addTearDown(model.dispose);
    await model.load();
    await model.loadAvailable();
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(repository.links, 1);
    expect(model.requiresRefresh, isTrue);
    expect(model.errorMessage, contains('Chưa xác nhận'));
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(repository.links, 1);
    expect(repository.posts, 0);
    await model.load();
    expect(model.requiresRefresh, isFalse);
    expect(model.notice, contains('Đã tải lại'));
  });

  test('uncertain unlink blocks writes until read refresh', () async {
    final repository = FakeBuzzerRepository()
      ..unlinkFailure = const BuzzerFailure(
        BuzzerFailureKind.uncertainMutation,
      );
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repository),
    );
    addTearDown(model.dispose);
    await model.load();
    // The fake starts without links; make the unlink target visible to the model.
    model.sources = BuzzerDetailDto.sourcesFromJson(linkedPirsResponse());
    await model.unlink('7');
    expect(repository.unlinks, 1);
    expect(model.requiresRefresh, isTrue);
    await model.unlink('7');
    expect(repository.unlinks, 1);
    expect(repository.posts, 0);
    await model.load();
    expect(model.requiresRefresh, isFalse);
  });

  test(
    'real POST transport failure requires refresh and is not replayed',
    () async {
      final harness = BuzzerManagementTransportHarness();
      addTearDown(harness.dispose);
      await harness.model.load();
      await harness.model.loadAvailable();

      await harness.model.link(const BuzzerLinkConfiguration('7', 0, 1000));
      expect(harness.postCalls, 1);
      expect(harness.model.requiresRefresh, isTrue);
      expect(harness.model.errorMessage, contains('Chưa xác nhận'));
      await harness.model.link(const BuzzerLinkConfiguration('7', 0, 1000));
      await harness.model.unlink('7');
      expect(harness.postCalls, 1);
      expect(harness.deleteCalls, 0);

      await harness.model.load();
      expect(harness.model.requiresRefresh, isFalse);
      harness.failPost = false;
      await harness.model.link(const BuzzerLinkConfiguration('7', 0, 1000));
      expect(harness.postCalls, 2);
      expect(
        harness.requests.where((request) => request.url.path.endsWith('/test')),
        isEmpty,
      );
    },
  );

  test(
    'real DELETE transport failure requires refresh and is not replayed',
    () async {
      final harness = BuzzerManagementTransportHarness();
      addTearDown(harness.dispose);
      await harness.model.load();
      await harness.model.loadAvailable();

      await harness.model.unlink('7');
      expect(harness.deleteCalls, 1);
      expect(harness.model.requiresRefresh, isTrue);
      expect(harness.model.errorMessage, contains('Chưa xác nhận'));
      await harness.model.link(const BuzzerLinkConfiguration('7', 0, 1000));
      await harness.model.unlink('7');
      expect(harness.postCalls, 0);
      expect(harness.deleteCalls, 1);

      await harness.model.load();
      expect(harness.model.requiresRefresh, isFalse);
      harness.failDelete = false;
      await harness.model.unlink('7');
      expect(harness.deleteCalls, 2);
      expect(
        harness.requests.where((request) => request.url.path.endsWith('/test')),
        isEmpty,
      );
    },
  );

  test(
    'successful unlink with failed refresh stays blocked until recovery',
    () async {
      final repository = FakeBuzzerRepository();
      final model = BuzzerProvider(
        deviceId: '42',
        useCases: BuzzerUseCases(repository),
      );
      addTearDown(model.dispose);
      await model.load();
      model.sources = BuzzerDetailDto.sourcesFromJson(linkedPirsResponse());
      repository.failAvailable = true;
      await model.unlink('7');
      expect(repository.unlinks, 1);
      expect(model.requiresRefresh, isTrue);
      expect(model.errorMessage, contains('Đã cập nhật'));
      expect(model.cooldownSeconds, 0);
      await model.unlink('7');
      expect(repository.unlinks, 1);
      expect(repository.posts, 0);
      repository.failAvailable = false;
      await model.load();
      expect(model.requiresRefresh, isFalse);
      expect(model.notice, contains('Đã cập nhật'));
    },
  );

  test('definite validation rejection allows a corrected submission', () async {
    final repository = FakeBuzzerRepository()
      ..linkFailure = const BuzzerFailure(BuzzerFailureKind.configuration);
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repository),
    );
    addTearDown(model.dispose);
    await model.load();
    await model.loadAvailable();
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(model.requiresRefresh, isFalse);
    repository.linkFailure = null;
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(repository.links, 2);
    expect(model.requiresRefresh, isFalse);
  });

  test('pending link cannot be submitted twice or start Test Buzzer', () async {
    final repository = FakeBuzzerRepository()..deferLink = true;
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repository),
    );
    addTearDown(model.dispose);
    await model.load();
    await model.loadAvailable();
    final first = model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    expect(model.isMutating, isTrue);
    await model.link(const BuzzerLinkConfiguration('7', 0, 1000));
    await model.test();
    expect(repository.links, 1);
    expect(repository.posts, 0);
    repository.pendingLink!.complete();
    await first;
    expect(model.isMutating, isFalse);
  });

  test('available PIR decoding and replacement privacy', () {
    final values = BuzzerDetailDto.availableFromJson({
      'status': 'success',
      'available_pirs': [
        {
          'id': 7,
          'name': null,
          'chip_id': 'pir7',
          'linked_buzzer': null,
          'requires_confirmation': true,
        },
        {
          'id': 8,
          'name': 'PIR 8',
          'chip_id': 'pir8',
          'linked_buzzer': {'id': 99, 'name': null},
          'requires_confirmation': true,
        },
      ],
    });
    expect(values.first.name, isNull);
    expect(values.first.confirmation('42'), contains('Cấu hình hiện có'));
    expect(values.last.linkedBuzzer?.name, isNull);
    expect(values.last.confirmation('42'), contains('Buzzer hiện tại'));
  });

  test('link validation and refresh do not invoke Test Buzzer', () async {
    expect(const BuzzerLinkConfiguration('7', 0, 100).isValid, isTrue);
    expect(const BuzzerLinkConfiguration('7', 0, 10000).isValid, isTrue);
    expect(const BuzzerLinkConfiguration('7', -1, 1000).isValid, isFalse);
    expect(const BuzzerLinkConfiguration('7', 0, 10001).isValid, isFalse);
    final repository = FakeBuzzerRepository();
    final model = BuzzerProvider(
      deviceId: '42',
      useCases: BuzzerUseCases(repository),
    );
    await model.load();
    await model.loadAvailable();
    await model.link(const BuzzerLinkConfiguration('7', 0, 100));
    expect(repository.links, 1);
    expect(repository.posts, 0);
    expect(model.requiresRefresh, isFalse);
    model.dispose();
  });

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

  test('linked PIRs and history accept nullable and stored scalar values', () {
    final sources = BuzzerDetailDto.sourcesFromJson({
      'status': 'success',
      'linked_pirs': [
        {
          'id': 7,
          'name': null,
          'chip_id': 'pir7',
          'relay_index': '2',
          'longlast': '1500',
        },
        {
          'id': 8,
          'name': null,
          'chip_id': 'pir8',
          'relay_index': null,
          'longlast': false,
        },
      ],
    });
    expect(sources[0].name, 'pir7');
    expect(sources[0].relayIndex, 2);
    expect(sources[0].relayDisplay, '2');
    expect(sources[0].longlast, 1500);
    expect(sources[1].relayIndex, isNull);
    expect(sources[1].longlastDisplay, isNull);
    final events = BuzzerDetailDto.eventsFromJson({
      'status': 'success',
      'events': [
        {
          'id': 123,
          'event_type': 'motion_detected',
          'occurred_at': '2026-09-19T10:29:00+07:00',
          'pir': {'id': 7, 'name': null, 'chip_id': 'pir7'},
          'relay_index': 'legacy',
          'longlast': null,
        },
      ],
    });
    expect(events.single.sourceName, 'pir7');
    expect(events.single.relayIndex, isNull);
    expect(events.single.relayDisplay, 'legacy');
    expect(events.single.longlast, isNull);
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

  test(
    'management uses numeric POST body and DELETE without Test Buzzer',
    () async {
      final requests = <http.Request>[];
      final source = BinblogDeviceDataSource(
        username: 'fixture',
        password: 'fixture',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/login') {
            return http.Response('{"token":"token"}', 200);
          }
          if (request.url.path.endsWith('/available_pirs')) {
            return http.Response(
              '{"status":"success","available_pirs":[{"id":7,"name":null,"chip_id":"pir7","linked_buzzer":null,"requires_confirmation":true}]}',
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response(
              '{"status":"success","linked_pir":{"id":7,"name":null,"chip_id":"pir7","relay_index":0,"longlast":100}}',
              200,
            );
          }
          if (request.method == 'DELETE') {
            return http.Response('{"status":"success","pir_id":7}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(source.close);
      final repository = BinblogBuzzerRepository(source);
      expect(
        (await repository.loadAvailablePirs('42')).single.requiresConfirmation,
        isTrue,
      );
      await repository.link('42', const BuzzerLinkConfiguration('7', 0, 100));
      await repository.unlink('42', '7');
      expect(
        requests.where((request) => request.url.path.endsWith('/test')),
        isEmpty,
      );
      final post = requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/linked_pirs'),
      );
      expect(jsonDecode(post.body), {
        'pir_id': 7,
        'relay_index': 0,
        'longlast': 100,
      });
      expect(
        requests.singleWhere((request) => request.method == 'DELETE').url.path,
        '/api/devices/42/buzzer/linked_pirs/7',
      );
      expect(
        requests.singleWhere((request) => request.method == 'DELETE').body,
        isEmpty,
      );
    },
  );

  test(
    'management ambiguous statuses and bodies require read refresh',
    () async {
      for (final method in ['POST', 'DELETE']) {
        for (final status in [200, 429, 503]) {
          final source = BinblogDeviceDataSource(
            username: 'fixture',
            password: 'fixture',
            client: MockClient((request) async {
              if (request.url.path == '/api/login') {
                return http.Response('{"token":"token"}', 200);
              }
              return http.Response('{"status":"error"}', status);
            }),
          );
          final repository = BinblogBuzzerRepository(source);
          addTearDown(source.close);
          await expectLater(
            method == 'POST'
                ? repository.link(
                    '42',
                    const BuzzerLinkConfiguration('7', 0, 1000),
                  )
                : repository.unlink('42', '7'),
            throwsA(
              isA<BuzzerFailure>().having(
                (error) => error.kind,
                'kind',
                BuzzerFailureKind.uncertainMutation,
              ),
            ),
          );
        }
      }
    },
  );

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
