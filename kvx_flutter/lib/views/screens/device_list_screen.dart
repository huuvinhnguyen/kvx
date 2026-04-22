import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/device_viewmodel.dart';
import '../widgets/filter_bar.dart';
import '../widgets/device_row.dart';
import 'add_device_sheet.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceViewModel(),
      child: const _DeviceListContent(),
    );
  }
}

class _DeviceListContent extends StatelessWidget {
  const _DeviceListContent();

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
      body: Consumer<DeviceViewModel>(
        builder: (context, viewModel, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilterBar(
                  selectedIndex: DeviceFilter.values.indexOf(viewModel.selectedFilter),
                  filters: DeviceFilter.values.map((f) => f.displayName).toList(),
                  onFilterChanged: (index) {
                    viewModel.setFilter(DeviceFilter.values[index]);
                  },
                ),
              ),
              if (viewModel.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: viewModel.refresh,
                  child: viewModel.filteredDevices.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: viewModel.filteredDevices.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final device = viewModel.filteredDevices[index];
                            return Dismissible(
                              key: Key(device.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.red,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => viewModel.deleteDevices([device]),
                              child: DeviceRow(
                                device: device,
                                onTap: () => viewModel.toggleStatus(device),
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
    final viewModel = context.read<DeviceViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddDeviceSheet(viewModel: viewModel),
    );
  }
}
