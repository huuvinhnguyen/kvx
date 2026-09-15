import '../../domain/entities/pir_statistics.dart';
import '../datasources/binblog_device_datasource.dart';

abstract class PirRepository {
  Future<PirStatistics> statistics(String chipId, String date);
  Future<List<PirDay>> heatmap(String chipId);
}

class BinblogPirRepository implements PirRepository {
  final BinblogDeviceDataSource source;
  BinblogPirRepository(this.source);
  @override
  Future<PirStatistics> statistics(String chipId, String date) async {
    final stats = PirStatistics.fromJson(
      await source.getJson('api/devices/motion_stats', {
        'chip_id': chipId,
        'date': date,
      }),
    );
    if (stats.date != date) {
      throw const FormatException('Ngày thống kê không khớp.');
    }
    return stats;
  }

  @override
  Future<List<PirDay>> heatmap(String chipId) async {
    final json = await source.getJson('api/devices/motion_heatmap', {
      'chip_id': chipId,
      'days': '30',
    });
    final days = (json['data'] as List)
        .map((v) => PirDay.fromJson(v as Map<String, dynamic>))
        .toList();
    if (days.map((d) => d.date).toSet().length != days.length) {
      throw const FormatException('Ngày thống kê bị trùng.');
    }
    return days;
  }
}
