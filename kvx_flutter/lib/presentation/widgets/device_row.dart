import 'package:flutter/material.dart';
import '../../domain/entities/device.dart';

class DeviceRow extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const DeviceRow({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        device.type.icon,
        size: 28,
        color: device.status.color,
      ),
      title: Text(
        device.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(
            device.type.displayName,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(width: 6),
          const Text('•', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 6),
          StatusBadge(status: device.status),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final DeviceStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          status.displayName,
          style: TextStyle(
            fontSize: 12,
            color: status.color,
          ),
        ),
      ],
    );
  }
}
