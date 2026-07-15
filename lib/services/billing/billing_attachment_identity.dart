final class BillingAttachmentIdentity {
  static const supportedExtensions = <String>['.avif', '.webp', '.jpg'];

  final int transactionId;
  final int billingJobId;
  final int index;

  const BillingAttachmentIdentity({
    required this.transactionId,
    required this.billingJobId,
    required this.index,
  });

  String get originKey => 'billing:$billingJobId:$index';

  String get baseName => 'tx_${transactionId}_${billingJobId}_$index';

  Iterable<String> get candidateFileNames =>
      supportedExtensions.map((extension) => '$baseName$extension');

  String? findExisting(Set<String> names) {
    for (final candidate in candidateFileNames) {
      if (names.contains(candidate)) return candidate;
    }
    return null;
  }
}
