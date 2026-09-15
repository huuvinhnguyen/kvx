import 'package:flutter/material.dart';
import '../../domain/entities/device.dart';

class DeviceControlFooter extends StatelessWidget {
  final Device device;
  final VoidCallback? onRestart;
  final VoidCallback? onResetWifi;
  final bool isLoading;

  const DeviceControlFooter({
    super.key,
    required this.device,
    this.onRestart,
    this.onResetWifi,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Device info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tag, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    device.id,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              if (device.firmwareVersion != null || device.appVersion != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (device.firmwareVersion != null) ...[
                      const Icon(Icons.settings, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        device.firmwareVersion!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (device.firmwareVersion != null && device.appVersion != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|', style: TextStyle(color: Colors.grey)),
                      ),
                    if (device.appVersion != null) ...[
                      const Icon(Icons.phone_android, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        device.appVersion!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),

        // Control buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _showConfirmDialog(
                          context: context,
                          title: 'Khởi động lại',
                          message: 'Bạn có chắc muốn khởi động lại thiết bị không?',
                          onConfirm: onRestart ?? () {},
                        ),
                icon: const Icon(Icons.restart_alt),
                label: const Text(
                  '🔁 Khởi động lại thiết bị',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _showConfirmDialog(
                          context: context,
                          title: 'Thay đổi WiFi',
                          message: 'Thiết bị sẽ xóa WiFi cũ và chuyển sang chế độ cấu hình mới. Bạn có chắc không?',
                          onConfirm: onResetWifi ?? () {},
                        ),
                icon: const Icon(Icons.wifi_off),
                label: const Text(
                  '📶 Thay đổi WiFi',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }
}
