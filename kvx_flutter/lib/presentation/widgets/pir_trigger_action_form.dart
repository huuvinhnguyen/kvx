import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/pir_trigger_action.dart';
import '../providers/pir_trigger_actions_provider.dart';

class PirTriggerActionForm extends StatefulWidget {
  final PirTriggerActionsProvider model;
  final PirTriggerAction? action;
  const PirTriggerActionForm({super.key, required this.model, this.action});
  @override
  State<PirTriggerActionForm> createState() => _PirTriggerActionFormState();
}

class _PirTriggerActionFormState extends State<PirTriggerActionForm> {
  int? targetId;
  int? relayIndex;
  late final TextEditingController duration;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    targetId = widget.action?.target?.id;
    relayIndex = widget.action?.relayIndex;
    duration = TextEditingController(
      text: widget.action?.durationMs.toString() ?? '',
    );
    enabled = widget.action?.enabled ?? true;
  }

  @override
  void dispose() {
    duration.dispose();
    super.dispose();
  }

  List<PirTriggerTarget> get choices {
    final current = widget.action?.target?.id;
    if (current == null) return widget.model.availableTargetsForAdd;
    return widget.model.targets
        .where(
          (target) =>
              target.id == current ||
              !widget.model.actions.any(
                (action) =>
                    action.id != widget.action?.id &&
                    action.target?.id == target.id,
              ),
        )
        .toList();
  }

  PirTriggerTarget? get target {
    final values = widget.model.targets.where((value) => value.id == targetId);
    return values.isEmpty ? null : values.single;
  }

  PirTriggerActionDraft? get draft {
    final milliseconds = int.tryParse(duration.text);
    if (targetId == null || relayIndex == null || milliseconds == null) {
      return null;
    }
    final value = PirTriggerActionDraft(
      targetId: targetId!,
      relayIndex: relayIndex!,
      durationMs: milliseconds,
      enabled: enabled,
    );
    return value.isValid(widget.model.targets) ? value : null;
  }

  bool get canInteract =>
      !widget.model.isBusy &&
      (widget.action == null ? widget.model.canAdd : widget.model.canManage);

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: widget.model,
    child: Consumer<PirTriggerActionsProvider>(
      builder: (context, _, child) => _buildForm(context),
    ),
  );

  Widget _buildForm(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.action == null ? 'Thêm hành động' : 'Sửa hành động'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: targetId,
          decoration: const InputDecoration(labelText: 'Target'),
          items: choices
              .map(
                (value) => DropdownMenuItem(
                  value: value.id,
                  child: Text('${value.displayName} · ${value.typeLabel}'),
                ),
              )
              .toList(),
          onChanged: !canInteract
              ? null
              : (value) => setState(() {
                  targetId = value;
                  relayIndex = target?.relayIndexes.first;
                  if (target case final selected?) {
                    duration.text = selected.durationBounds.minimum.toString();
                  }
                }),
        ),
        if (target case final selected?) ...[
          const SizedBox(height: 12),
          SelectableText(
            selected.chipId,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: selected.relayIndexes.contains(relayIndex)
                ? relayIndex
                : null,
            decoration: const InputDecoration(labelText: 'Relay'),
            items: selected.relayIndexes
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('Relay $value'),
                  ),
                )
                .toList(),
            onChanged: !canInteract
                ? null
                : (value) => setState(() => relayIndex = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: duration,
            enabled: canInteract,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Thời lượng (ms)',
              helperText:
                  'Cho phép: ${selected.durationBounds.minimum}–${selected.durationBounds.maximum} ms',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Độ trễ'),
          trailing: Text('${widget.action?.delayMs ?? 0} ms'),
        ),
        Text(
          (widget.action?.delayMs ?? 0) > 0
              ? 'Độ trễ cũ chỉ đọc. Lưu thay đổi sẽ đặt về 0 ms.'
              : 'Độ trễ cố định 0 ms và không thể chỉnh sửa.',
          style: TextStyle(
            color: (widget.action?.delayMs ?? 0) > 0
                ? Colors.orange
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bật hành động'),
          value: enabled,
          onChanged: !canInteract
              ? null
              : (value) => setState(() => enabled = value),
        ),
        const SizedBox(height: 20),
        if (widget.model.isBusy)
          Semantics(
            liveRegion: true,
            label: 'Đang lưu và tải lại trạng thái máy chủ',
            child: const LinearProgressIndicator(),
          ),
        if (widget.model.isBusy) const SizedBox(height: 12),
        FilledButton(
          onPressed: draft == null || !canInteract ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    final value = draft;
    if (value == null) return;
    if ((widget.action?.delayMs ?? 0) > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đặt độ trễ về 0 ms?'),
          content: const Text(
            'Backend không còn hỗ trợ độ trễ khác 0 cho hành động được cập nhật.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu và đặt về 0'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (widget.action case final action?) {
      await widget.model.update(action, value);
    } else {
      await widget.model.create(value);
    }
    if (mounted && widget.model.phase == PirTriggerPhase.ready) {
      Navigator.pop(context);
    }
  }
}
