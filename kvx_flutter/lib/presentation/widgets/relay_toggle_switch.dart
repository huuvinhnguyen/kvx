import 'package:flutter/material.dart';

class RelayToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool enabled;

  const RelayToggleSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label = 'BẬT / TẮT',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.only(top: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 2.0,
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            label,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
