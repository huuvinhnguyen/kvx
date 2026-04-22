import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/device_filter.dart';
import '../providers/device_provider.dart';
import '../widgets/filter_bar.dart';
import '../widgets/device_row.dart';
import 'add_device_sheet.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDeviceSheet(context),
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilterBar(
                  selectedIndex: DeviceFilter.values.indexOf(provider.selectedFilter),
                  filters: DeviceFilter.values.map((f) => f.displayName).toList(),
                  onFilterChanged: (index) {
                    provider.setFilter(DeviceFilter.values[index]);
                  },
                ),
              ),
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: provider.filteredDevices.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: provider.filteredDevices.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final device = provider.filteredDevices[index];
                            return Dismissible(
                              key: Key(device.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.red,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => provider.deleteDevice(device),
                              child: DeviceRow(
                                device: device,
                                onTap: () => provider.toggleStatus(device),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No devices found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const AddDeviceSheet(),
    );
  }
}
