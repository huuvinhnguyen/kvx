import 'package:flutter/material.dart';
import '../../domain/entities/device.dart';

class DeviceInfoHeader extends StatelessWidget {
  final Device device;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const DeviceInfoHeader({
    super.key,
    required this.device,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDeviceIcon(device.type),
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildStatusBadge(context),
                    ],
                  ),
                ),
              ],
            ),
            if (device.lastConnected != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Lần kết nối cuối: ${_formatDateTime(device.lastConnected!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (onRefresh != null)
                    IconButton(
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onPressed: isLoading ? null : onRefresh,
                      tooltip: 'Làm mới',
                    ),
                ],
              ),
            ],
            if (device.firmwareVersion != null || device.appVersion != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (device.firmwareVersion != null) ...[
                    const Icon(Icons.settings, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Firmware: ${device.firmwareVersion}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                  if (device.firmwareVersion != null && device.appVersion != null)
                    const SizedBox(width: 16),
                  if (device.appVersion != null) ...[
                    const Icon(Icons.phone_android, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'App: ${device.appVersion}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color;
    String text;

    switch (device.status) {
      case DeviceStatus.online:
        color = Colors.green;
        text = 'Trực tuyến';
        break;
      case DeviceStatus.offline:
        color = Colors.grey;
        text = 'Ngoại tuyến';
        break;
      case DeviceStatus.busy:
        color = Colors.orange;
        text = 'Bận';
        break;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.pir:
        return Icons.sensors;
      case DeviceType.switchDevice:
        return Icons.power;
      case DeviceType.temperature:
        return Icons.thermostat;
      case DeviceType.iPhone:
      case DeviceType.iPad:
      case DeviceType.simulator:
        return Icons.phone_android;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
