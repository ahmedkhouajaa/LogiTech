import 'ssl_pinning_stub.dart'
    if (dart.library.io) 'ssl_pinning_io.dart';

class SslPinningService {
  static void initialize() {
    initializeSslPinning();
  }
}
