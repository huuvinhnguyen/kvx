import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/data/datasources/binblog_device_datasource.dart';
import 'package:kvx_flutter/data/models/binblog_device_dto.dart';
import 'package:kvx_flutter/data/repositories/pir_repository.dart';
import 'package:kvx_flutter/domain/entities/device.dart';
import 'package:kvx_flutter/domain/entities/pir_statistics.dart';
import 'package:kvx_flutter/presentation/screens/pir_detail_screen.dart';

class FakePir implements PirRepository {
  final requests = <String, Completer<PirStatistics>>{};
  bool fail = false;
  @override
  Future<PirStatistics> statistics(String chipId, String date) {
    if (fail) return Future.error(Exception('Không kết nối được'));
    return (requests[date] = Completer<PirStatistics>()).future;
  }

  @override
  Future<List<PirDay>> heatmap(String chipId) async => [
    PirDay(pirDateKey(pirToday()), 3),
  ];
  void finish(String date, int total) {
    requests[date]!.complete(
      PirStatistics(date, [total, ...List.filled(23, 0)], total),
    );
  }
}

void main() {
  test(
    'history parses UTC timestamps and limits to 20 events; old API remains supported',
    () {
      final json = <String, dynamic>{
        'date': '2026-09-15',
        'values': List.filled(24, 0),
        'total': 0,
      };
      expect(PirStatistics.fromJson(json).recentEvents, isNull);
      json['recent_events'] = List.generate(
        22,
        (i) => {
          'id': i,
          'event_type': 'motion_detected',
          'occurred_at': '2026-09-14T18:00:00Z',
        },
      );
      final events = PirStatistics.fromJson(json).recentEvents!;
      expect(events.length, 20);
      expect(events.first.displayTime, '15/09/2026 01:00:00');
    },
  );

  test('PIR mapping preserves chip identity', () {
    final device = BinblogDeviceDto.fromJson({
      'id': 64,
      'name': 'PIR',
      'chip_id': 'esp32_testpir',
      'device_type': 'pir',
    }).toDomain();
    expect(device.type, DeviceType.pir);
    expect(device.copyWith(name: 'New').chipId, 'esp32_testpir');
  });
  test('invalid hourly totals and counts are rejected', () {
    expect(
      () => PirStatistics.fromJson({
        'date': '2026-09-15',
        'values': [1],
        'total': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => PirStatistics.fromJson({
        'date': '2026-09-15',
        'values': List.filled(24, 0),
        'total': 10,
      }),
      throwsFormatException,
    );
    expect(
      [0, 1, 3, 4, 8, 9, 15, 16].map((n) => PirDay('2026-09-15', n).level),
      [0, 1, 1, 2, 2, 3, 3, 4],
    );
  });
  test('authenticated API uses chip_id and server values contract', () async {
    final source = BinblogDeviceDataSource(
      username: 'test',
      password: 'test',
      client: MockClient((request) async {
        if (request.url.path == '/api/login') {
          return http.Response('{"token":"test-token"}', 200);
        }
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.queryParameters['chip_id'], 'esp32_testpir');
        expect(request.url.queryParameters['date'], '2026-09-15');
        return http.Response(
          jsonEncode({
            'date': '2026-09-15',
            'values': List.filled(24, 1),
            'total': 24,
          }),
          200,
        );
      }),
    );
    expect(
      (await BinblogPirRepository(
        source,
      ).statistics('esp32_testpir', '2026-09-15')).total,
      24,
    );
    source.close();
  });
  testWidgets(
    'changing dates ignores an older response and supports heatmap selection',
    (tester) async {
      final repo = FakePir();
      final today = pirDateKey(pirToday());
      final yesterday = pirDateKey(
        DateTime(pirToday().year, pirToday().month, pirToday().day - 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PirDetailScreen(
            device: const Device(
              id: '64',
              chipId: 'esp32_testpir',
              name: 'PIR phòng khách',
              type: DeviceType.pir,
              status: DeviceStatus.online,
            ),
            repository: repo,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Ngày trước'));
      await tester.pump();
      repo.finish(yesterday, 0);
      await tester.pumpAndSettle();
      expect(find.text('Không có chuyển động trong ngày này.'), findsOneWidget);
      repo.finish(today, 20);
      await tester.pumpAndSettle();
      expect(find.text('Không có chuyển động trong ngày này.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('day-$today')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey('day-$today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('day-$today')));
      await tester.pump();
      repo.finish(today, 3);
      await tester.pumpAndSettle();
      expect(find.text('Không có chuyển động trong ngày này.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('error offers retry', (tester) async {
    final repo = FakePir()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: PirDetailScreen(
          device: const Device(
            id: '64',
            chipId: 'test',
            name: 'PIR',
            type: DeviceType.pir,
            status: DeviceStatus.online,
          ),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    repo.finish(pirDateKey(pirToday()), 0);
    await tester.pumpAndSettle();
    expect(find.text('Không có chuyển động trong ngày này.'), findsOneWidget);
  });
}
