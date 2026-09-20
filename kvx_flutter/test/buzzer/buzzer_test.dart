import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/data/datasources/binblog_device_datasource.dart';
import 'package:kvx_flutter/data/models/buzzer_detail_dto.dart';
import 'package:kvx_flutter/data/repositories/binblog_buzzer_repository.dart';
import 'package:kvx_flutter/domain/entities/buzzer_detail.dart';

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
    {'id': 7, 'name': 'Hall PIR', 'chip_id': 'ESP32_PIR_01', 'relay_index': 0, 'longlast': 1000},
  ],
};

Map<String, dynamic> historyResponse() => {
  'status': 'success',
  'events': [
    {'id': 123, 'event_type': 'motion_detected', 'occurred_at': '2026-09-19T10:29:00+07:00', 'pir': {'id': 7, 'name': 'Hall PIR', 'chip_id': 'ESP32_PIR_01'}, 'relay_index': 0, 'longlast': 1000},
  ],
};

void main() {
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
    expect(() => BuzzerDetailDto.fromDetailJson({'status': 'success', 'buzzer': {'device_type': 'pir'}}), throwsA(isA<BuzzerFailure>()));
    final invalid = historyResponse()..['events'] = List.generate(21, (_) => historyResponse()['events'][0]);
    expect(() => BuzzerDetailDto.eventsFromJson(invalid), throwsA(isA<BuzzerFailure>()));
  });

  test('repository uses device-scoped paths and Bearer authentication', () async {
    final requests = <http.Request>[];
    final source = BinblogDeviceDataSource(
      username: 'fixture', password: 'fixture',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/login') return http.Response('{"token":"fixture-token"}', 200);
        expect(request.headers['Authorization'], 'Bearer fixture-token');
        expect(request.headers['Accept'], 'application/json');
        switch (request.url.path) {
          case '/api/devices/42/buzzer': return http.Response(jsonEncode(detailResponse()), 200);
          case '/api/devices/42/buzzer/linked_pirs': return http.Response(jsonEncode(linkedPirsResponse()), 200);
          case '/api/devices/42/buzzer/history': return http.Response(jsonEncode(historyResponse()), 200);
          case '/api/devices/42/buzzer/test': return http.Response('{"status":"success","message":"Command sent to MQTT broker","relay_index":0,"longlast":1000}', 200);
          default: return http.Response('{}', 404);
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
    expect(requests.map((request) => request.url.path), containsAll(['/api/devices/42/buzzer', '/api/devices/42/buzzer/linked_pirs', '/api/devices/42/buzzer/history', '/api/devices/42/buzzer/test']));
  });

  test('429 maps to server cooldown and 404 maps to unavailable', () async {
    final source = BinblogDeviceDataSource(username: 'fixture', password: 'fixture', client: MockClient((request) async {
      if (request.url.path == '/api/login') return http.Response('{"token":"token"}', 200);
      if (request.url.path.endsWith('/test')) return http.Response('{"status":"error"}', 429, headers: {'retry-after': '5'});
      return http.Response('{"status":"error"}', 404);
    }));
    addTearDown(source.close);
    final repository = BinblogBuzzerRepository(source);
    await expectLater(repository.load('42'), throwsA(isA<BuzzerFailure>().having((e) => e.kind, 'kind', BuzzerFailureKind.unavailable)));
    await expectLater(repository.test('42'), throwsA(isA<BuzzerFailure>().having((e) => e.retryAfterSeconds, 'retry', 5)));
  });
}
