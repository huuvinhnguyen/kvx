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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              device.type.icon,
              size: 24,
              color: device.status.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                device.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 100,
              child: Center(
                child: StatusBadge(status: device.status),
              ),
            ),
          ],
        ),
      ),
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
