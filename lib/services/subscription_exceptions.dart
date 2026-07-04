class SubscriptionRequiredException implements Exception {
  SubscriptionRequiredException([this.message = 'subscription_required']);
  final String message;

  @override
  String toString() => message;
}

class QuotaExceededException implements Exception {
  QuotaExceededException({this.action, this.limit, this.used});
  final String? action;
  final int? limit;
  final int? used;

  @override
  String toString() => 'quota_exceeded';
}
