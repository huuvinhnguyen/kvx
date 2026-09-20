import '../../domain/entities/buzzer_detail.dart';
import '../../domain/repositories/buzzer_repository.dart';

class BuzzerUseCases {
  final BuzzerRepository repository;
  const BuzzerUseCases(this.repository);

  Future<(BuzzerDetail, List<BuzzerSource>, List<BuzzerMotionEvent>)> load(String deviceId) async {
    final results = await Future.wait<Object>([
      repository.load(deviceId),
      repository.loadLinkedPirs(deviceId),
      repository.loadHistory(deviceId),
    ]);
    final detail = results[0] as BuzzerDetail;
    if (detail.id != deviceId) throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    return (detail, results[1] as List<BuzzerSource>, results[2] as List<BuzzerMotionEvent>);
  }

  Future<BuzzerTestReceipt> test(String deviceId) => repository.test(deviceId);
}
