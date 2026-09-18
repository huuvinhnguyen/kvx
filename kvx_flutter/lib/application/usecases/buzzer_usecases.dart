import '../../domain/entities/buzzer_detail.dart';
import '../../domain/repositories/buzzer_repository.dart';

class BuzzerUseCases {
  final BuzzerRepository repository;
  const BuzzerUseCases(this.repository);

  Future<BuzzerDetail> load(String deviceId) async {
    final detail = await repository.load(deviceId);
    if (detail.id != deviceId) {
      throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    }
    return detail;
  }

  Future<BuzzerCommandReceipt> execute(
    BuzzerDetail detail,
    BuzzerCommand command,
  ) {
    if (command == BuzzerCommand.test && !detail.canTest) {
      throw const BuzzerFailure(BuzzerFailureKind.configuration);
    }
    return repository.send(detail.id, command);
  }
}
