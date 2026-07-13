import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_avif/flutter_avif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import '../providers.dart';
import 'system/logger_service.dart';

TransactionAttachment? findExistingBillingJobAttachment({
  required Iterable<TransactionAttachment> attachments,
  required int transactionId,
  required int billingJobId,
  required int index,
}) {
  final stablePrefix = 'tx_${transactionId}_${billingJobId}_$index.';
  for (final attachment in attachments) {
    if (attachment.fileName.startsWith(stablePrefix)) return attachment;
  }
  return null;
}

/// 附件服务
/// 负责图片的选择、压缩、存储和管理
class AttachmentService {
  static const int maxAttachments = 9;
  static const int maxWidth = 1920;
  static const int maxHeight = 1920;
  static const int defaultQuality = 80;
  static const int thumbnailSize = 200;

  final Ref ref;
  final ImagePicker _picker = ImagePicker();

  AttachmentService(this.ref);

  /// 获取附件存储目录
  Future<Directory> getAttachmentDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/attachments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 获取缩略图缓存目录
  Future<Directory> getThumbnailDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final dir = Directory('${cacheDir.path}/attachment_thumbs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 从相册选择图片
  /// 返回选择的图片文件列表
  Future<List<File>> pickFromGallery({int maxCount = 9}) async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: _attachmentQuality,
      );
      return images.map((x) => File(x.path)).toList();
    } catch (e) {
      logger.error('AttachmentService', '从相册选择图片失败', e);
      return [];
    }
  }

  /// 拍照
  Future<File?> takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: _attachmentQuality,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      logger.error('AttachmentService', '拍照失败', e);
      return null;
    }
  }

  /// 保存附件
  /// 将图片压缩后保存到附件目录，并在数据库中创建记录
  Future<TransactionAttachment?> saveAttachment({
    required int transactionId,
    required File sourceFile,
    required int index,
  }) async {
    try {
      final dir = await getAttachmentDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final quality = _attachmentQuality;
      var format = ref.read(smartBillingAttachmentFormatProvider);
      var fileName =
          _buildAttachmentFileName(transactionId, timestamp, index, format);
      var destPath = '${dir.path}/$fileName';

      final saveStart = DateTime.now();
      logger.info(
        'AttachmentService',
        '附件保存开始: format=${format.storageKey}, quality=$quality',
      );

      // 压缩图片并保存
      var compressedFile = await _compressImage(
        sourceFile,
        destPath,
        format,
        quality: quality,
        copyOnFailure: format == SmartBillingAttachmentFormat.jpeg,
      );
      if (compressedFile == null &&
          format != SmartBillingAttachmentFormat.jpeg) {
        logger.warning(
            'AttachmentService', '${format.storageKey} 压缩失败，已回退为 JPEG');
        format = SmartBillingAttachmentFormat.jpeg;
        fileName =
            _buildAttachmentFileName(transactionId, timestamp, index, format);
        destPath = '${dir.path}/$fileName';
        compressedFile = await _compressImage(
          sourceFile,
          destPath,
          format,
          quality: quality,
          copyOnFailure: true,
        );
      }
      if (compressedFile == null) {
        logger.error('AttachmentService', '图片压缩失败');
        return null;
      }

      // 获取图片尺寸
      final imageInfo = await _getImageInfo(compressedFile.path);

      // 获取文件大小
      final fileSize = await compressedFile.length();

      // AVIF 缩略图需要从源图生成，避免依赖平台是否能直接解码 AVIF。
      if (format == SmartBillingAttachmentFormat.avif) {
        await _generateThumbnailFromSource(sourceFile, fileName);
      }

      // 保存到数据库
      final repo = ref.read(repositoryProvider);
      final id = await repo.createAttachment(
        transactionId: transactionId,
        fileName: fileName,
        originalName: path.basename(sourceFile.path),
        fileSize: fileSize,
        width: imageInfo?.width,
        height: imageInfo?.height,
        sortOrder: index,
      );

      final elapsed = DateTime.now().difference(saveStart).inMilliseconds;
      logger.info('AttachmentService', '附件保存成功: $fileName, elapsedMs=$elapsed');
      return repo.getAttachmentById(id);
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '保存附件失败', e, stackTrace);
      return null;
    }
  }

  Future<TransactionAttachment?> saveAttachmentWhenTransactionReady({
    required Future<int> transactionId,
    required File sourceFile,
    required int index,
    int? billingJobId,
  }) async {
    try {
      final dir = await getAttachmentDirectory();
      final txId = await transactionId;
      // Billing Job retries use one deterministic file key. A rolled-back old
      // owner may leave a file, but the next owner overwrites that same path
      // instead of producing another orphan attachment file.
      final timestamp =
          billingJobId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final quality = _attachmentQuality;
      var format = ref.read(smartBillingAttachmentFormatProvider);
      final repo = ref.read(repositoryProvider);
      if (billingJobId != null) {
        final existing = findExistingBillingJobAttachment(
          attachments: await repo.getAttachmentsByTransaction(txId),
          transactionId: txId,
          billingJobId: billingJobId,
          index: index,
        );
        if (existing != null) {
          logger.info(
            'AttachmentService',
            '附件幂等命中: jobId=$billingJobId, file=${existing.fileName}',
          );
          return existing;
        }
      }
      var tempFileName = _buildPendingAttachmentFileName(
        timestamp,
        index,
        format,
      );
      var tempPath = '${dir.path}/$tempFileName';

      final saveStart = DateTime.now();
      logger.info(
        'AttachmentService',
        '附件预处理开始: format=${format.storageKey}, quality=$quality',
      );

      var compressedFile = await _compressImage(
        sourceFile,
        tempPath,
        format,
        quality: quality,
        copyOnFailure: format == SmartBillingAttachmentFormat.jpeg,
      );
      if (compressedFile == null &&
          format != SmartBillingAttachmentFormat.jpeg) {
        logger.warning(
            'AttachmentService', '${format.storageKey} 压缩失败，已回退为 JPEG');
        format = SmartBillingAttachmentFormat.jpeg;
        tempFileName = _buildPendingAttachmentFileName(
          timestamp,
          index,
          format,
        );
        tempPath = '${dir.path}/$tempFileName';
        compressedFile = await _compressImage(
          sourceFile,
          tempPath,
          format,
          quality: quality,
          copyOnFailure: true,
        );
      }
      if (compressedFile == null) {
        logger.error('AttachmentService', '附件预处理失败');
        return null;
      }

      final fileName = _buildAttachmentFileName(txId, timestamp, index, format);
      final destPath = '${dir.path}/$fileName';
      final finalFile = await _moveFile(compressedFile, destPath);
      final imageInfo = await _getImageInfo(finalFile.path);
      final fileSize = await finalFile.length();

      if (format == SmartBillingAttachmentFormat.avif) {
        await _generateThumbnailFromSource(sourceFile, fileName);
      }

      final id = await repo.createAttachment(
        transactionId: txId,
        fileName: fileName,
        originalName: path.basename(sourceFile.path),
        fileSize: fileSize,
        width: imageInfo?.width,
        height: imageInfo?.height,
        sortOrder: index,
      );

      final elapsed = DateTime.now().difference(saveStart).inMilliseconds;
      logger.info('AttachmentService', '附件保存成功: $fileName, elapsedMs=$elapsed');
      return repo.getAttachmentById(id);
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '保存附件失败', e, stackTrace);
      return null;
    }
  }

  /// 批量保存附件
  Future<List<TransactionAttachment>> saveAttachments({
    required int transactionId,
    required List<File> sourceFiles,
    int startIndex = 0,
  }) async {
    final results = <TransactionAttachment>[];
    for (int i = 0; i < sourceFiles.length; i++) {
      final attachment = await saveAttachment(
        transactionId: transactionId,
        sourceFile: sourceFiles[i],
        index: startIndex + i,
      );
      if (attachment != null) {
        results.add(attachment);
      }
    }
    return results;
  }

  /// 删除附件
  Future<void> deleteAttachment(int attachmentId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final attachment = await repo.getAttachmentById(attachmentId);

      if (attachment != null) {
        // 删除原图文件
        final dir = await getAttachmentDirectory();
        final file = File('${dir.path}/${attachment.fileName}');
        if (await file.exists()) {
          await file.delete();
          logger.debug('AttachmentService', '已删除原图: ${attachment.fileName}');
        }

        // 删除缩略图
        await _deleteThumbnail(attachment.fileName);

        // 删除数据库记录
        await repo.deleteAttachment(attachmentId);
        logger.info('AttachmentService', '附件删除成功: ${attachment.fileName}');
      }
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '删除附件失败', e, stackTrace);
    }
  }

  /// 删除交易的所有附件
  Future<void> deleteAttachmentsByTransaction(int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final attachments = await repo.getAttachmentsByTransaction(transactionId);

      for (final attachment in attachments) {
        // 删除原图文件
        final dir = await getAttachmentDirectory();
        final file = File('${dir.path}/${attachment.fileName}');
        if (await file.exists()) {
          await file.delete();
        }

        // 删除缩略图
        await _deleteThumbnail(attachment.fileName);
      }

      // 删除所有数据库记录
      await repo.deleteAttachmentsByTransaction(transactionId);
      logger.info('AttachmentService', '已删除交易 $transactionId 的所有附件');
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '删除交易附件失败', e, stackTrace);
    }
  }

  /// 获取附件文件路径
  Future<String> getAttachmentPath(String fileName) async {
    final dir = await getAttachmentDirectory();
    return '${dir.path}/$fileName';
  }

  /// 获取缩略图路径
  /// 如果缩略图不存在，会自动生成
  Future<String?> getThumbnailPath(String fileName) async {
    try {
      final thumbDir = await getThumbnailDirectory();
      final thumbName = '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
      final thumbPath = '${thumbDir.path}/$thumbName';

      // 如果缩略图已存在，直接返回
      if (await File(thumbPath).exists()) {
        return thumbPath;
      }

      // 生成缩略图
      final attachmentDir = await getAttachmentDirectory();
      final sourcePath = '${attachmentDir.path}/$fileName';

      if (!await File(sourcePath).exists()) {
        logger.warning('AttachmentService', '原图不存在: $fileName');
        return null;
      }

      if (path.extension(fileName).toLowerCase() == '.avif') {
        return _generateThumbnailFromAvif(sourcePath, fileName);
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        thumbPath,
        minWidth: thumbnailSize,
        minHeight: thumbnailSize,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        logger.debug('AttachmentService', '生成缩略图: $thumbName');
        return thumbPath;
      }

      return null;
    } catch (e) {
      logger.error('AttachmentService', '获取缩略图失败', e);
      return null;
    }
  }

  /// 清理孤立图片（数据库中没有记录的图片文件）
  Future<int> cleanOrphanedAttachments() async {
    try {
      final dir = await getAttachmentDirectory();
      final repo = ref.read(repositoryProvider);

      int deletedCount = 0;
      final files = dir.listSync().whereType<File>();

      for (final file in files) {
        final fileName = path.basename(file.path);
        final exists = await repo.attachmentExistsByFileName(fileName);

        if (!exists) {
          await file.delete();
          await _deleteThumbnail(fileName);
          deletedCount++;
          logger.debug('AttachmentService', '清理孤立图片: $fileName');
        }
      }

      if (deletedCount > 0) {
        logger.info('AttachmentService', '清理了 $deletedCount 个孤立图片');
      }

      return deletedCount;
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '清理孤立图片失败', e, stackTrace);
      return 0;
    }
  }

  /// 获取附件目录总大小（字节）
  Future<int> getAttachmentDirectorySize() async {
    try {
      final dir = await getAttachmentDirectory();
      int totalSize = 0;

      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        totalSize += await file.length();
      }

      return totalSize;
    } catch (e) {
      logger.error('AttachmentService', '获取附件目录大小失败', e);
      return 0;
    }
  }

  // ============================================
  // 私有方法
  // ============================================

  int get _attachmentQuality {
    return ref.read(smartBillingAttachmentQualityProvider).clamp(5, 100);
  }

  /// 压缩图片
  Future<File?> _compressImage(
    File source,
    String targetPath,
    SmartBillingAttachmentFormat format, {
    required int quality,
    required bool copyOnFailure,
  }) async {
    try {
      if (format == SmartBillingAttachmentFormat.avif) {
        final start = DateTime.now();
        final result = await _compressAvifImage(source, targetPath, quality);
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        logger.info('AttachmentService', 'AVIF 编码结束: elapsedMs=$elapsed');
        return result;
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        targetPath,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: _compressFormat(format),
      );

      if (result != null) {
        return File(result.path);
      }

      if (!copyOnFailure) {
        return null;
      }

      // 如果压缩失败，直接复制原文件
      await source.copy(targetPath);
      return File(targetPath);
    } catch (e) {
      logger.error('AttachmentService', '压缩图片失败', e);
      if (!copyOnFailure) {
        return null;
      }

      // 尝试直接复制
      try {
        await source.copy(targetPath);
        return File(targetPath);
      } catch (copyError) {
        logger.error('AttachmentService', '复制图片也失败', copyError);
        return null;
      }
    }
  }

  Future<File?> _compressAvifImage(
    File source,
    String targetPath,
    int quality,
  ) async {
    final inputBytes = await _prepareAvifInputBytes(source, quality);
    if (inputBytes == null || inputBytes.isEmpty) {
      return null;
    }
    final quantizers = _avifQuantizersForQuality(quality);

    final avifBytes = await encodeAvif(
      inputBytes,
      speed: 8,
      minQuantizer: quantizers.min,
      maxQuantizer: quantizers.max,
      minQuantizerAlpha: quantizers.min,
      maxQuantizerAlpha: quantizers.max,
    );
    if (avifBytes.isEmpty) {
      return null;
    }

    final target = File(targetPath);
    await target.writeAsBytes(avifBytes, flush: true);
    return target;
  }

  Future<Uint8List?> _prepareAvifInputBytes(File source, int quality) async {
    final sourceInfo = await _getImageInfo(source.path);
    if (sourceInfo != null &&
        sourceInfo.width <= maxWidth &&
        sourceInfo.height <= maxHeight) {
      logger.info(
        'AttachmentService',
        'AVIF 跳过 JPEG 预处理: ${sourceInfo.width}x${sourceInfo.height}',
      );
      return source.readAsBytes();
    }

    try {
      logger.info(
        'AttachmentService',
        'AVIF JPEG 预处理开始: source=${sourceInfo == null ? "unknown" : "${sourceInfo.width}x${sourceInfo.height}"}',
      );
      final compressed = await FlutterImageCompress.compressWithFile(
        source.path,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed != null && compressed.isNotEmpty) {
        logger.info(
            'AttachmentService', 'AVIF JPEG 预处理完成: bytes=${compressed.length}');
        return compressed;
      }
    } catch (e) {
      logger.warning('AttachmentService', 'AVIF 前置压缩失败，尝试使用原图编码: $e');
    }

    return source.readAsBytes();
  }

  ({int min, int max}) _avifQuantizersForQuality(int quality) {
    final normalized = quality.clamp(5, 100);
    final max = (63 - (normalized * 0.5)).round().clamp(12, 43);
    final min = (max - 14).clamp(0, max);
    return (min: min, max: max);
  }

  String _buildAttachmentFileName(
    int transactionId,
    int timestamp,
    int index,
    SmartBillingAttachmentFormat format,
  ) {
    return 'tx_${transactionId}_${timestamp}_$index${_extensionForFormat(format)}';
  }

  String _buildPendingAttachmentFileName(
    int timestamp,
    int index,
    SmartBillingAttachmentFormat format,
  ) {
    return 'pending_${timestamp}_$index${_extensionForFormat(format)}';
  }

  Future<File> _moveFile(File source, String targetPath) async {
    try {
      return await source.rename(targetPath);
    } on FileSystemException {
      final target = await source.copy(targetPath);
      await source.delete();
      return target;
    }
  }

  String _extensionForFormat(SmartBillingAttachmentFormat format) {
    switch (format) {
      case SmartBillingAttachmentFormat.jpeg:
        return '.jpg';
      case SmartBillingAttachmentFormat.webp:
        return '.webp';
      case SmartBillingAttachmentFormat.avif:
        return '.avif';
    }
  }

  CompressFormat _compressFormat(SmartBillingAttachmentFormat format) {
    switch (format) {
      case SmartBillingAttachmentFormat.jpeg:
        return CompressFormat.jpeg;
      case SmartBillingAttachmentFormat.webp:
        return CompressFormat.webp;
      case SmartBillingAttachmentFormat.avif:
        throw UnsupportedError(
            'AVIF uses flutter_avif instead of CompressFormat');
    }
  }

  /// 获取图片尺寸信息
  Future<({int width, int height})?> _getImageInfo(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      return (width: image.width, height: image.height);
    } catch (e) {
      if (path.extension(imagePath).toLowerCase() == '.avif') {
        return _getAvifImageInfo(imagePath);
      }
      logger.error('AttachmentService', '获取图片尺寸失败', e);
      return null;
    }
  }

  Future<({int width, int height})?> _getAvifImageInfo(String imagePath) async {
    try {
      final frames = await decodeAvif(await File(imagePath).readAsBytes());
      if (frames.isEmpty) return null;
      final image = frames.first.image;
      return (width: image.width, height: image.height);
    } catch (e) {
      logger.error('AttachmentService', '获取 AVIF 图片尺寸失败', e);
      return null;
    }
  }

  Future<String?> _generateThumbnailFromSource(
    File source,
    String fileName,
  ) async {
    try {
      final thumbDir = await getThumbnailDirectory();
      final thumbName = '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
      final thumbPath = '${thumbDir.path}/$thumbName';

      if (await File(thumbPath).exists()) {
        return thumbPath;
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        thumbPath,
        minWidth: thumbnailSize,
        minHeight: thumbnailSize,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        logger.debug('AttachmentService', '生成 AVIF 缩略图: $thumbName');
        return thumbPath;
      }
    } catch (e) {
      logger.error('AttachmentService', '生成 AVIF 缩略图失败', e);
    }
    return null;
  }

  Future<String?> _generateThumbnailFromAvif(
    String sourcePath,
    String fileName,
  ) async {
    try {
      final frames = await decodeAvif(await File(sourcePath).readAsBytes());
      if (frames.isEmpty) return null;

      final frameBytes =
          await frames.first.image.toByteData(format: ui.ImageByteFormat.png);
      if (frameBytes == null) return null;

      final thumbnailBytes = await FlutterImageCompress.compressWithList(
        frameBytes.buffer.asUint8List(),
        minWidth: thumbnailSize,
        minHeight: thumbnailSize,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (thumbnailBytes.isEmpty) return null;

      final thumbDir = await getThumbnailDirectory();
      final thumbName = '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
      final thumbPath = '${thumbDir.path}/$thumbName';
      await File(thumbPath).writeAsBytes(thumbnailBytes, flush: true);
      logger.debug('AttachmentService', '重新生成 AVIF 缩略图: $thumbName');
      return thumbPath;
    } catch (e) {
      logger.error('AttachmentService', '重新生成 AVIF 缩略图失败', e);
      return null;
    }
  }

  /// 删除缩略图
  Future<void> _deleteThumbnail(String fileName) async {
    try {
      final thumbDir = await getThumbnailDirectory();
      final thumbName = '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
      final thumbFile = File('${thumbDir.path}/$thumbName');

      if (await thumbFile.exists()) {
        await thumbFile.delete();
        logger.debug('AttachmentService', '已删除缩略图: $thumbName');
      }
    } catch (e) {
      logger.error('AttachmentService', '删除缩略图失败', e);
    }
  }
}

/// AttachmentService Provider
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref);
});

/// 交易附件列表 Provider
final transactionAttachmentsProvider =
    StreamProvider.family<List<TransactionAttachment>, int>(
  (ref, transactionId) {
    final repo = ref.watch(repositoryProvider);
    return repo.watchAttachmentsByTransaction(transactionId);
  },
);

/// 附件列表刷新触发器
final attachmentListRefreshProvider = StateProvider<int>((ref) => 0);

/// 交易附件数量 Provider
final attachmentCountProvider = FutureProvider.family<int, int>(
  (ref, transactionId) async {
    ref.watch(attachmentListRefreshProvider);
    final repo = ref.read(repositoryProvider);
    return repo.getAttachmentCountByTransaction(transactionId);
  },
);

/// 批量获取交易附件数量 Provider
final attachmentCountsProvider =
    FutureProvider.family<Map<int, int>, List<int>>(
  (ref, transactionIds) async {
    if (transactionIds.isEmpty) return {};
    final repo = ref.read(repositoryProvider);
    return repo.getAttachmentCountsForTransactions(transactionIds);
  },
);
