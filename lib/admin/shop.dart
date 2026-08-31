/// A shop's subscription record as stored on the backend.
class Shop {
  Shop({
    required this.id,
    required this.name,
    this.userId,
    this.username,
    this.phone,
    this.ownerName,
    this.plan = 'basic_49',
    required this.createdAt,
    required this.trialEndsAt,
    required this.expiresAt,
    this.isBlocked = false,
    this.lastSeenAt,
    this.appVersion,
    this.adminNote,
  });

  final String id;
  final String name;

  /// Firebase UID of the owner, once they have signed in. Null = the admin
  /// registered this shop but the owner has not activated it yet.
  final String? userId;

  /// Display label the admin set for this shop.
  final String? username;

  /// The phone number the owner signs in with (E.164).
  final String? phone;
  final String? ownerName;

  bool get activated => userId != null && userId!.isNotEmpty;
  final String plan;
  final DateTime createdAt;
  final DateTime trialEndsAt;
  final DateTime expiresAt;
  final bool isBlocked;
  final DateTime? lastSeenAt;
  final String? appVersion;
  final String? adminNote;

  bool get expired => DateTime.now().isAfter(expiresAt);

  /// Active = paid-up (or in trial) and not switched off by the admin.
  bool get active => !isBlocked && !expired;

  bool get onTrial => !expired && DateTime.now().isBefore(trialEndsAt);

  /// Whole days remaining (negative once expired).
  int get daysLeft => expiresAt.difference(DateTime.now()).inHours ~/ 24;

  ShopStatus get status {
    if (isBlocked) return ShopStatus.blocked;
    if (expired) return ShopStatus.expired;
    if (onTrial) return ShopStatus.trial;
    if (daysLeft <= 5) return ShopStatus.expiringSoon;
    return ShopStatus.active;
  }

  static DateTime _date(dynamic v) =>
      v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();

  static DateTime? _dateOrNull(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'My Tea Shop',
        userId: j['user_id'] as String?,
        username: j['username'] as String?,
        phone: j['phone'] as String?,
        ownerName: j['owner_name'] as String?,
        plan: (j['plan'] as String?) ?? 'basic_49',
        createdAt: _date(j['created_at']),
        trialEndsAt: _date(j['trial_ends_at']),
        expiresAt: _date(j['expires_at']),
        isBlocked: (j['is_blocked'] as bool?) ?? false,
        lastSeenAt: _dateOrNull(j['last_seen_at']),
        appVersion: j['app_version'] as String?,
        adminNote: j['admin_note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'user_id': userId,
        'username': username,
        'phone': phone,
        'owner_name': ownerName,
        'plan': plan,
        'created_at': createdAt.toIso8601String(),
        'trial_ends_at': trialEndsAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_blocked': isBlocked,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'app_version': appVersion,
        'admin_note': adminNote,
      };
}

enum ShopStatus {
  active,
  trial,
  expiringSoon,
  expired,
  blocked;

  String get label {
    switch (this) {
      case ShopStatus.active:
        return 'Active';
      case ShopStatus.trial:
        return 'Trial';
      case ShopStatus.expiringSoon:
        return 'Expiring soon';
      case ShopStatus.expired:
        return 'Expired';
      case ShopStatus.blocked:
        return 'Blocked';
    }
  }
}
