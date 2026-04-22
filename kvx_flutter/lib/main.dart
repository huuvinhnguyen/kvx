import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/datasources/in_memory_device_datasource.dart';
import 'data/repositories/device_repository_impl.dart';
import 'application/usecases/device_usecases.dart';
import 'presentation/providers/device_provider.dart';
import 'presentation/screens/device_list_screen.dart';

void main() {
  runApp(const KvxApp());
}

class KvxApp extends StatelessWidget {
  const KvxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dataSource = InMemoryDeviceDataSource();
    final repository = DeviceRepositoryImpl(dataSource);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(
            getDevicesUseCase: GetDevicesUseCase(repository),
            addDeviceUseCase: AddDeviceUseCase(repository),
            deleteDeviceUseCase: DeleteDeviceUseCase(repository),
            toggleStatusUseCase: ToggleDeviceStatusUseCase(repository),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'KVX',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const DeviceListScreen(),
      ),
    );
  }
}
