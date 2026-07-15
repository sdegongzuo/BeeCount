import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import 'billing_attachment_identity.dart';

typedef BillingAttachmentDimensions = ({int width, int height});
typedef BillingAttachmentUpsert = Future<TransactionAttachment> Function(
  String originKey,
  File publishedFile,
  BillingAttachmentDimensions dimensions,
);

final class BillingAttachmentPublishLeaseLost implements Exception {
  final BillingJobLease lease;

  const BillingAttachmentPublishLeaseLost(this.lease);

  @override
  String toString() =>
      'BillingAttachmentPublishLeaseLost(jobId=${lease.jobId})';
}

final class BillingAttachmentInvalidImage implements Exception {
  final String filePath;

  const BillingAttachmentInvalidImage(this.filePath);

  @override
  String toString() => 'BillingAttachmentInvalidImage($filePath)';
}

final class BillingAttachmentPublisher {
  const BillingAttachmentPublisher();

  Future<TransactionAttachment> publish({
    required BillingAttachmentIdentity identity,
    required File preparedFile,
    required String finalFileName,
    required BillingJobLease lease,
    required Future<bool> Function(BillingJobLease lease) isLeaseOwner,
    required BillingAttachmentUpsert createOrGet,
  }) async {
    final directory = path.dirname(path.absolute(preparedFile.path));
    final finalPath = path.join(directory, finalFileName);
    if (path.basename(finalFileName) != finalFileName ||
        !identity.candidateFileNames.contains(finalFileName) ||
        path.dirname(path.absolute(finalPath)) != directory ||
        path.extension(preparedFile.path).toLowerCase() !=
            path.extension(finalFileName).toLowerCase()) {
      throw ArgumentError('prepared and stable files must share one format');
    }

    final preparedDimensions = await decodeCompleteBillingJobAttachmentBytes(
      await preparedFile.readAsBytes(),
      extension: path.extension(finalFileName),
    );
    if (preparedDimensions == null) {
      throw BillingAttachmentInvalidImage(preparedFile.path);
    }

    final lockFile =
        File(path.join(directory, '${identity.baseName}.publish.lock'));
    final lock = await lockFile.open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      final stableFile = File(finalPath);
      final stableDimensions = await _decodeFileIfComplete(stableFile);
      if (!await isLeaseOwner(lease)) {
        throw BillingAttachmentPublishLeaseLost(lease);
      }

      if (stableDimensions != null) {
        return await createOrGet(
          identity.originKey,
          stableFile,
          stableDimensions,
        );
      }

      final publishedFile = await _replaceAtomically(preparedFile, stableFile);
      return await createOrGet(
        identity.originKey,
        publishedFile,
        preparedDimensions,
      );
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  Future<BillingAttachmentDimensions?> _decodeFileIfComplete(File file) async {
    if (!await file.exists()) return null;
    try {
      return decodeCompleteBillingJobAttachmentBytes(
        await file.readAsBytes(),
        extension: path.extension(file.path),
      );
    } on FileSystemException {
      return null;
    }
  }

  Future<File> _replaceAtomically(File prepared, File stable) async {
    if (Platform.isWindows) {
      final sourcePath = prepared.path.toNativeUtf16();
      final targetPath = stable.path.toNativeUtf16();
      try {
        final result = MoveFileEx(
          sourcePath,
          targetPath,
          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
        );
        if (result == 0) {
          final error = GetLastError();
          throw FileSystemException(
            'Atomic MoveFileEx failed with Windows error $error',
            prepared.path,
            OSError('MoveFileEx', error),
          );
        }
        return stable;
      } finally {
        calloc.free(sourcePath);
        calloc.free(targetPath);
      }
    }

    // Android and the other supported POSIX platforms map this same-directory
    // operation to rename(2), which replaces the target atomically.
    return prepared.rename(stable.path);
  }
}

Future<BillingAttachmentDimensions?> decodeCompleteBillingJobAttachmentBytes(
  Uint8List bytes, {
  required String extension,
}) async {
  if (bytes.isEmpty || !_matchesFormat(bytes, extension)) return null;
  try {
    if (extension.toLowerCase() == '.avif') {
      final frames = await decodeAvif(bytes);
      if (frames.isEmpty) return null;
      final image = frames.first.image;
      final dimensions = (width: image.width, height: image.height);
      image.dispose();
      return dimensions;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final dimensions = (width: image.width, height: image.height);
      image.dispose();
      return dimensions;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}

bool _matchesFormat(Uint8List bytes, String extension) {
  switch (extension.toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    case '.webp':
      return bytes.length >= 12 &&
          _asciiAt(bytes, 0, 'RIFF') &&
          _asciiAt(bytes, 8, 'WEBP');
    case '.avif':
      return bytes.length >= 12 &&
          _asciiAt(bytes, 4, 'ftyp') &&
          (_asciiAt(bytes, 8, 'avif') || _asciiAt(bytes, 8, 'avis'));
    default:
      return false;
  }
}

bool _asciiAt(Uint8List bytes, int offset, String value) {
  if (bytes.length < offset + value.length) return false;
  for (var i = 0; i < value.length; i++) {
    if (bytes[offset + i] != value.codeUnitAt(i)) return false;
  }
  return true;
}
