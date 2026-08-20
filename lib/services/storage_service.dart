import 'storage/storage_stub.dart'
    if (dart.library.io) 'storage/storage_io.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const int minRequiredBytes = 100 * 1024 * 1024; // 100 MB free minimum requirement

  Future<bool> hasMinimumStorage({int requiredBytes = minRequiredBytes}) async {
    final freeBytes = await getAvailableStorageBytes();
    if (freeBytes == null) return true; // If undetectable, assume OK
    return freeBytes >= requiredBytes;
  }

  Future<int?> getAvailableStorageBytes() async {
    return getPlatformAvailableStorageBytes();
  }
}
