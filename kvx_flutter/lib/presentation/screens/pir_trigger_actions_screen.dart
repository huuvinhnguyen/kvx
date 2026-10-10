import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/usecases/pir_trigger_action_use_cases.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/pir_trigger_action.dart';
import '../providers/pir_trigger_actions_provider.dart';
import '../widgets/pir_trigger_action_form.dart';

class PirTriggerActionsScreen extends StatelessWidget {
  final Device device;
  final PirTriggerActionUseCases useCases;
  const PirTriggerActionsScreen({
    super.key,
    required this.device,
    required this.useCases,
  });

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => PirTriggerActionsProvider(
      chipId: device.chipId ?? '',
      useCases: useCases,
    )..load(),
    child: const _PirTriggerActionsBody(),
  );
}

class _PirTriggerActionsBody extends StatelessWidget {
  const _PirTriggerActionsBody();
  @override
  Widget build(BuildContext context) => Consumer<PirTriggerActionsProvider>(
    builder: (context, model, _) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hành động PIR'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: model.isBusy ? null : model.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton:
            model.canAdd && model.availableTargetsForAdd.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: model.isBusy
                    ? null
                    : () => _openForm(context, model),
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: model.load,
          child: _content(context, model),
        ),
      );
    },
  );

  Widget _content(BuildContext context, PirTriggerActionsProvider model) {
    if (model.phase == PirTriggerPhase.loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final header = <Widget>[
      if (model.phase == PirTriggerPhase.mutating)
        const LinearProgressIndicator(semanticsLabel: 'Đang gửi cập nhật'),
      if (model.phase == PirTriggerPhase.reconciling)
        const ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Đang tải lại trạng thái máy chủ…'),
        ),
      if (model.notice case final notice?)
        ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(notice),
        ),
      if (model.errorMessage case final error?)
        ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.orange),
          title: Text(error),
          subtitle: model.needsLogin
              ? const Text('Hãy đăng nhập lại từ màn hình thiết bị.')
              : null,
        ),
      if (model.phase == PirTriggerPhase.uncertain)
        const ListTile(
          title: Text('Kết quả cập nhật chưa xác định'),
          subtitle: Text(
            'Mọi chỉnh sửa đang bị khóa. Hãy tải lại để đối soát với máy chủ.',
          ),
        ),
      if (model.phase == PirTriggerPhase.featureDisabled)
        const ListTile(title: Text('Tính năng đang tạm tắt trên máy chủ.')),
      if (model.phase == PirTriggerPhase.invalidLegacy)
        const ListTile(
          title: Text('Cấu hình legacy không hợp lệ'),
          subtitle: Text(
            'Cần đối soát trên máy chủ trước khi có thể chỉnh sửa.',
          ),
        ),
    ];
    if (model.phase == PirTriggerPhase.legacy) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          ...header,
          const ListTile(title: Text('Cấu hình legacy · Chỉ đọc')),
          if (model.actions case [final action])
            _actionCard(context, model, action, editable: false),
          FilledButton(
            onPressed: model.canMigrateLegacy && !model.isBusy
                ? () => _confirmMigration(context, model)
                : null,
            child: const Text('Chuyển sang hành động được quản lý'),
          ),
          if (!model.canMigrateLegacy)
            const Text(
              'Target legacy không còn khả dụng; hãy tải lại hoặc đối soát trên máy chủ.',
            ),
        ],
      );
    }
    if (model.phase == PirTriggerPhase.ready) {
      if (model.actions.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            ...header,
            const SizedBox(height: 100),
            const Icon(Icons.account_tree_outlined, size: 56),
            const Center(child: Text('PIR chưa có hành động nào.')),
          ],
        );
      }
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        header: Column(children: header),
        itemCount: model.actions.length,
        onReorder: model.isBusy || !model.canManage ? (_, _) {} : model.reorder,
        itemBuilder: (context, index) {
          final action = model.actions[index];
          return KeyedSubtree(
            key: ValueKey(action.id),
            child: _actionCard(context, model, action, editable: true),
          );
        },
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ...header,
        if (!model.isBusy && !model.needsLogin)
          OutlinedButton.icon(
            onPressed: model.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context,
    PirTriggerActionsProvider model,
    PirTriggerAction action, {
    required bool editable,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${action.position + 1}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.target?.displayName ?? 'Target không còn khả dụng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (action.origin == PirTriggerActionOrigin.legacy)
                const Chip(label: Text('LEGACY')),
              Icon(
                action.enabled ? Icons.check_circle : Icons.pause_circle,
                color: action.enabled ? Colors.green : Colors.grey,
              ),
            ],
          ),
          if (action.target case final target?)
            SelectableText(
              '${target.typeLabel} · ${target.chipId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            'Relay ${action.relayIndex} · ${action.durationMs} ms · Trễ ${action.delayMs} ms',
          ),
          if (editable)
            Row(
              children: [
                TextButton(
                  onPressed: model.isBusy
                      ? null
                      : () => _openForm(context, model, action),
                  child: const Text('Sửa'),
                ),
                TextButton(
                  onPressed: model.isBusy
                      ? null
                      : () => _confirmDelete(context, model, action),
                  child: const Text('Xóa'),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  void _openForm(
    BuildContext context,
    PirTriggerActionsProvider model, [
    PirTriggerAction? action,
  ]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PirTriggerActionForm(model: model, action: action),
    ),
  );
  Future<void> _confirmDelete(
    BuildContext context,
    PirTriggerActionsProvider model,
    PirTriggerAction action,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hành động?'),
        content: const Text(
          'Thao tác chỉ thay đổi cấu hình và không gửi MQTT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (yes == true) await model.delete(action);
  }

  Future<void> _confirmMigration(
    BuildContext context,
    PirTriggerActionsProvider model,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chuyển cấu hình legacy?'),
        content: const Text(
          'Cấu hình cũ sẽ thành một hành động được quản lý. Thiết bị không bị kích hoạt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chuyển cấu hình'),
          ),
        ],
      ),
    );
    if (yes == true) await model.migrateLegacy();
  }
}
