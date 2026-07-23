import 'payment_method_semantics.dart';

PaymentMethodNormalizationResult canonicalizePaymentMethodInput(
  String? input,
) {
  return const PaymentMethodSemantics().canonicalize(input);
}
