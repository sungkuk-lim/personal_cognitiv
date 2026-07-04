class SubscriptionStatus {
  const SubscriptionStatus({
    required this.tier,
    required this.status,
    this.expiresAt,
    this.productId,
    this.chatUsed = 0,
    this.embeddingUsed = 0,
    this.visionUsed = 0,
  });

  final String tier;
  final String status;
  final DateTime? expiresAt;
  final String? productId;
  final int chatUsed;
  final int embeddingUsed;
  final int visionUsed;

  bool get isProActive {
    if (tier != 'pro') return false;
    if (!const {'active', 'trialing'}.contains(status)) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  factory SubscriptionStatus.free() => const SubscriptionStatus(
        tier: 'free',
        status: 'inactive',
      );

  factory SubscriptionStatus.fromMaps({
    Map<String, dynamic>? subscription,
    Map<String, dynamic>? usage,
  }) {
    if (subscription == null) return SubscriptionStatus.free();
    return SubscriptionStatus(
      tier: subscription['tier'] as String? ?? 'free',
      status: subscription['status'] as String? ?? 'inactive',
      expiresAt: subscription['expires_at'] != null
          ? DateTime.tryParse(subscription['expires_at'] as String)
          : null,
      productId: subscription['product_id'] as String?,
      chatUsed: usage?['chat_count'] as int? ?? 0,
      embeddingUsed: usage?['embedding_count'] as int? ?? 0,
      visionUsed: usage?['vision_count'] as int? ?? 0,
    );
  }
}
