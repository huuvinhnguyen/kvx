import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/application/usecases/pir_trigger_action_use_cases.dart';
import 'package:kvx_flutter/data/datasources/binblog_device_datasource.dart';
import 'package:kvx_flutter/data/models/pir_trigger_action_dto.dart';
import 'package:kvx_flutter/data/repositories/binblog_pir_trigger_action_repository.dart';
import 'package:kvx_flutter/domain/entities/pir_trigger_action.dart';
import 'package:kvx_flutter/domain/entities/device.dart';
import 'package:kvx_flutter/domain/repositories/pir_trigger_action_repository.dart';
import 'package:kvx_flutter/presentation/providers/pir_trigger_actions_provider.dart';
import 'package:kvx_flutter/presentation/screens/pir_trigger_actions_screen.dart';
import 'package:kvx_flutter/presentation/widgets/pir_trigger_action_form.dart';

Map<String, dynamic> actionJson({
  int id = 9,
  int targetId = 2,
  int position = 0,
  int delay = 0,
}) => {
  'id': id,
  'origin': 'persisted',
  'action_type': 'relay_pulse',
  'target': {
    'id': targetId,
    'name': 'Hall buzzer',
    'chip_id': 'buzz/2',
    'device_type': 'buzzer',
  },
  'relay_index': 0,
  'duration_ms': 1000,
  'delay_ms': delay,
  'enabled': true,
  'position': position,
};
Map<String, dynamic> configurationJson([
  List<Map<String, dynamic>> actions = const [],
]) => {
  'status': 'success',
  'configuration_mode': actions.isEmpty ? 'none' : 'actions',
  'source_device': {'id': 1, 'name': 'PIR', 'chip_id': 'pir/a'},
  'actions': actions,
};
Map<String, dynamic> targetsJson() => {
  'status': 'success',
  'targets': [
    {
      'id': 2,
      'chip_id': 'buzz/2',
      'name': 'Hall buzzer',
      'device_type': 'buzzer',
      'relay_indexes': [0, 1],
      'duration_ms': {'minimum': 100, 'maximum': 10000},
    },
    {
      'id': 3,
      'chip_id': 'switch3',
      'name': null,
      'device_type': 'switch',
      'relay_indexes': [0],
      'duration_ms': {'minimum': 100, 'maximum': 86400000},
    },
  ],
};

class FakeTriggerRepository implements PirTriggerActionRepository {
  PirTriggerConfiguration configuration = configurationFromJson(
    configurationJson(),
  );
  List<PirTriggerTarget> targets = targetsFromJson(targetsJson());
  int creates = 0;
  int updates = 0;
  int deletes = 0;
  int reorders = 0;
  int migrations = 0;
  int loads = 0;
  Object? mutationError;
  Object? loadError;
  Completer<void>? pendingCreate;
  Completer<void>? pendingUpdate;
  @override
  Future<PirTriggerConfiguration> loadConfiguration(String chipId) async {
    loads++;
    if (loadError case final error?) throw error;
    return configuration;
  }

  @override
  Future<List<PirTriggerTarget>> loadTargets(String chipId) async {
    if (loadError case final error?) throw error;
    return targets;
  }

  @override
  Future<void> create(String chipId, PirTriggerActionDraft draft) async {
    creates++;
    if (mutationError case final error?) throw error;
    await pendingCreate?.future;
  }

  @override
  Future<void> update(
    String chipId,
    int actionId,
    PirTriggerActionDraft draft,
  ) async {
    updates++;
    if (mutationError case final error?) throw error;
    await pendingUpdate?.future;
  }

  @override
  Future<void> delete(String chipId, int actionId) async {
    deletes++;
  }

  @override
  Future<void> migrateLegacy(String chipId) async {
    migrations++;
  }

  @override
  Future<void> reorder(String chipId, List<int> actionIds) async {
    reorders++;
  }
}

class DeferredLoadRepository extends FakeTriggerRepository {
  final configurationLoads = <Completer<PirTriggerConfiguration>>[];
  final targetLoads = <Completer<List<PirTriggerTarget>>>[];

  @override
  Future<PirTriggerConfiguration> loadConfiguration(String chipId) {
    final completer = Completer<PirTriggerConfiguration>();
    configurationLoads.add(completer);
    return completer.future;
  }

  @override
  Future<List<PirTriggerTarget>> loadTargets(String chipId) {
    final completer = Completer<List<PirTriggerTarget>>();
    targetLoads.add(completer);
    return completer.future;
  }
}

void main() {
  const draft = PirTriggerActionDraft(
    targetId: 2,
    relayIndex: 0,
    durationMs: 1000,
    enabled: true,
  );

  test('maps none, persisted and legacy invariants with server metadata', () {
    expect(
      configurationFromJson(configurationJson()).mode,
      PirTriggerConfigurationMode.empty,
    );
    final persisted = configurationFromJson(configurationJson([actionJson()]));
    expect(persisted.actions.single.id, 9);
    expect(targetsFromJson(targetsJson()).first.relayIndexes, [0, 1]);
    expect(draft.isValid(targetsFromJson(targetsJson())), isTrue);
    final legacy = configurationFromJson({
      'status': 'success',
      'configuration_mode': 'legacy',
      'source_device': {'id': 1, 'name': null, 'chip_id': 'pir'},
      'actions': [
        {...actionJson(), 'id': null, 'origin': 'legacy'},
      ],
    });
    expect(legacy.actions.single.origin, PirTriggerActionOrigin.legacy);
    expect(
      () => configurationFromJson({
        ...configurationJson(),
        'configuration_mode': 'unknown',
      }),
      throwsA(isA<PirTriggerFailure>()),
    );
  });

  test(
    'repository uses exact methods, encoded path, zero delay and bodyless delete/migration',
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
          if (request.method == 'GET' &&
              request.url.path.endsWith('/targets')) {
            return http.Response(jsonEncode(targetsJson()), 200);
          }
          if (request.method == 'GET') {
            return http.Response(jsonEncode(configurationJson()), 200);
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/migrate_legacy')) {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'migrated': true,
                'mode': 'actions',
                'action': actionJson(),
              }),
              200,
            );
          }
          if (request.method == 'DELETE') {
            return http.Response('{"status":"success","action_id":9}', 200);
          }
          if (request.method == 'PUT' && request.url.path.endsWith('/order')) {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'actions': [
                  actionJson(),
                  actionJson(id: 10, targetId: 3, position: 1),
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'status': 'success', 'action': actionJson()}),
              201,
            );
          }
          return http.Response(
            jsonEncode({'status': 'success', 'action': actionJson()}),
            200,
          );
        }),
      );
      addTearDown(source.close);
      final repository = BinblogPirTriggerActionRepository(source);
      await repository.loadConfiguration('pir/a');
      await repository.loadTargets('pir/a');
      await repository.create('pir/a', draft);
      await repository.update('pir/a', 9, draft);
      await repository.reorder('pir/a', [9, 10]);
      await repository.delete('pir/a', 9);
      await repository.migrateLegacy('pir/a');
      final mutations = requests
          .where(
            (request) =>
                request.url.path != '/api/login' && request.method != 'GET',
          )
          .toList();
      expect(mutations.map((request) => request.method), [
        'POST',
        'PUT',
        'PUT',
        'DELETE',
        'POST',
      ]);
      expect(
        requests.where((request) => request.url.path.endsWith('/test')),
        isEmpty,
      );
      expect(
        requests.any((request) => request.url.toString().contains('pir%2Fa')),
        isTrue,
      );
      expect(jsonDecode(mutations.first.body)['delay_ms'], 0);
      expect(
        jsonDecode(mutations[1].body),
        containsPair('action_type', 'relay_pulse'),
      );
      expect(jsonDecode(mutations[1].body), containsPair('delay_ms', 0));
      expect(jsonDecode(mutations[2].body)['action_ids'], [9, 10]);
      expect(mutations[3].body, isEmpty);
      expect(mutations[4].body, isEmpty);
    },
  );

  test(
    'structured rejection remains definite and malformed success is uncertain',
    () async {
      Future<PirTriggerFailure> failureFor(http.Response response) async {
        final source = BinblogDeviceDataSource(
          username: 'x',
          password: 'x',
          client: MockClient(
            (request) async => request.url.path == '/api/login'
                ? http.Response('{"token":"t"}', 200)
                : response,
          ),
        );
        final repository = BinblogPirTriggerActionRepository(source);
        addTearDown(source.close);
        try {
          await repository.create('pir', draft);
          fail('expected failure');
        } on PirTriggerFailure catch (error) {
          return error;
        }
      }

      expect(
        (await failureFor(
          http.Response(
            '{"status":"error","code":"action_limit_reached","message":"limit"}',
            409,
          ),
        )).kind,
        PirTriggerFailureKind.rejected,
      );
      expect(
        (await failureFor(http.Response('{"status":"success"}', 201))).kind,
        PirTriggerFailureKind.uncertainMutation,
      );
    },
  );

  test(
    'feature-disabled reads remain distinguishable from connection errors',
    () async {
      final source = BinblogDeviceDataSource(
        username: 'x',
        password: 'x',
        client: MockClient(
          (request) async => request.url.path == '/api/login'
              ? http.Response('{"token":"t"}', 200)
              : http.Response(
                  '{"status":"error","code":"feature_disabled","message":"disabled"}',
                  503,
                ),
        ),
      );
      addTearDown(source.close);

      await expectLater(
        BinblogPirTriggerActionRepository(source).loadConfiguration('pir'),
        throwsA(
          isA<PirTriggerFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                PirTriggerFailureKind.featureDisabled,
              )
              .having((failure) => failure.code, 'code', 'feature_disabled'),
        ),
      );
    },
  );

  test('each non-create malformed mutation receipt is uncertain', () async {
    Future<PirTriggerFailure> failureFor(
      Future<void> Function(BinblogPirTriggerActionRepository repository)
      operation,
    ) async {
      final source = BinblogDeviceDataSource(
        username: 'x',
        password: 'x',
        client: MockClient(
          (request) async => request.url.path == '/api/login'
              ? http.Response('{"token":"t"}', 200)
              : http.Response('{"status":"success"}', 200),
        ),
      );
      addTearDown(source.close);
      try {
        await operation(BinblogPirTriggerActionRepository(source));
        fail('expected uncertain mutation');
      } on PirTriggerFailure catch (error) {
        return error;
      }
    }

    final failures = [
      await failureFor((repository) => repository.update('pir', 9, draft)),
      await failureFor((repository) => repository.delete('pir', 9)),
      await failureFor((repository) => repository.reorder('pir', [9, 10])),
      await failureFor((repository) => repository.migrateLegacy('pir')),
    ];
    expect(
      failures.map((failure) => failure.kind),
      everyElement(PirTriggerFailureKind.uncertainMutation),
    );
  });

  test(
    'legacy state is read-only and migration requires an eligible target',
    () async {
      final repository = FakeTriggerRepository()
        ..configuration = configurationFromJson({
          'status': 'success',
          'configuration_mode': 'legacy',
          'source_device': {'id': 1, 'name': 'PIR', 'chip_id': 'pir'},
          'actions': [
            {...actionJson(), 'id': null, 'origin': 'legacy'},
          ],
        });
      final model = PirTriggerActionsProvider(
        chipId: 'pir',
        useCases: PirTriggerActionUseCases(repository),
      );
      addTearDown(model.dispose);
      await model.load();
      final legacy = model.actions.single;
      expect(model.phase, PirTriggerPhase.legacy);
      expect(model.canMigrateLegacy, isTrue);

      await model.create(draft);
      await model.update(legacy, draft);
      await model.delete(legacy);
      expect(
        (repository.creates, repository.updates, repository.deletes),
        (0, 0, 0),
      );
      await model.migrateLegacy();
      expect(repository.migrations, 1);

      repository.targets = const [];
      await model.load();
      expect(model.canMigrateLegacy, isFalse);
    },
  );

  test('an older load cannot replace a newer authoritative snapshot', () async {
    final repository = DeferredLoadRepository();
    final model = PirTriggerActionsProvider(
      chipId: 'pir',
      useCases: PirTriggerActionUseCases(repository),
    );
    addTearDown(model.dispose);

    final first = model.load();
    await Future<void>.delayed(Duration.zero);
    final second = model.load();
    await Future<void>.delayed(Duration.zero);
    final oldConfiguration = configurationFromJson(configurationJson());
    final newConfiguration = PirTriggerConfiguration(
      PirTriggerConfigurationMode.empty,
      const PirTriggerSource(1, 'new snapshot', 'pir'),
      const [],
    );
    repository.configurationLoads[1].complete(newConfiguration);
    repository.targetLoads[1].complete(repository.targets);
    await second;
    repository.configurationLoads[0].complete(oldConfiguration);
    repository.targetLoads[0].complete(const []);
    await first;

    expect(model.snapshot?.configuration.source.name, 'new snapshot');
  });

  test(
    'uncertain write and failed reconciliation block writes until refresh succeeds',
    () async {
      final repository = FakeTriggerRepository()
        ..mutationError = const PirTriggerFailure(
          PirTriggerFailureKind.uncertainMutation,
          'uncertain',
        )
        ..loadError = const PirTriggerFailure(
          PirTriggerFailureKind.connection,
          'offline',
        );
      final model = PirTriggerActionsProvider(
        chipId: 'pir',
        useCases: PirTriggerActionUseCases(repository),
      );
      addTearDown(model.dispose);
      repository.loadError = null;
      await model.load();
      repository.loadError = const PirTriggerFailure(
        PirTriggerFailureKind.connection,
        'offline',
      );
      await model.create(draft);
      expect(model.phase, PirTriggerPhase.uncertain);
      expect(repository.creates, 1);
      await model.create(draft);
      expect(repository.creates, 1);
      repository
        ..mutationError = null
        ..loadError = null;
      await model.load();
      expect(model.phase, PirTriggerPhase.ready);
      await model.create(draft);
      expect(repository.creates, 2);
      expect(model.phase, PirTriggerPhase.ready);
    },
  );

  test('one mutation gate blocks duplicate submissions', () async {
    final repository = FakeTriggerRepository()
      ..pendingCreate = Completer<void>();
    final model = PirTriggerActionsProvider(
      chipId: 'pir',
      useCases: PirTriggerActionUseCases(repository),
    );
    addTearDown(model.dispose);
    await model.load();
    final first = model.create(draft);
    await Future<void>.delayed(Duration.zero);
    await model.create(draft);
    expect(repository.creates, 1);
    repository.pendingCreate!.complete();
    await first;
    expect(model.phase, PirTriggerPhase.ready);
  });

  testWidgets('a null target renders no retained target identity', (
    tester,
  ) async {
    final repository = FakeTriggerRepository()
      ..configuration = configurationFromJson({
        ...configurationJson([actionJson()]),
        'actions': [
          {...actionJson(), 'target': null},
        ],
      });
    await tester.pumpWidget(
      MaterialApp(
        home: PirTriggerActionsScreen(
          device: const Device(
            id: '1',
            name: 'PIR',
            chipId: 'pir',
            type: DeviceType.pir,
            status: DeviceStatus.online,
          ),
          useCases: PirTriggerActionUseCases(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Target không còn khả dụng'), findsOneWidget);
    expect(find.textContaining('Hall buzzer'), findsNothing);
    expect(find.textContaining('buzz/2'), findsNothing);
  });

  testWidgets(
    'form locks every control during delayed mutation and reconciliation',
    (tester) async {
      final repository = FakeTriggerRepository()
        ..configuration = configurationFromJson(
          configurationJson([actionJson()]),
        )
        ..pendingUpdate = Completer<void>();
      final model = PirTriggerActionsProvider(
        chipId: 'pir',
        useCases: PirTriggerActionUseCases(repository),
      );
      addTearDown(model.dispose);
      await model.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PirTriggerActionForm(
                      model: model,
                      action: model.actions.single,
                    ),
                  ),
                ),
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pump();

      expect(repository.updates, 1);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>).first,
            )
            .onChanged,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(
        find.bySemanticsLabel('Đang lưu và tải lại trạng thái máy chủ'),
        findsOneWidget,
      );
      await tester.tap(find.text('Lưu'), warnIfMissed: false);
      expect(repository.updates, 1);

      repository.pendingUpdate!.complete();
      await tester.pumpAndSettle();
      expect(repository.updates, 1);
      expect(find.text('Mở form'), findsOneWidget);
      expect(model.phase, PirTriggerPhase.ready);
    },
  );
}
