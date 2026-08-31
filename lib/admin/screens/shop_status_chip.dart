import 'package:flutter/material.dart';

import '../shop.dart';

Color shopStatusColor(ShopStatus s) {
  switch (s) {
    case ShopStatus.active:
      return const Color(0xFF2E7D32);
    case ShopStatus.trial:
      return const Color(0xFF1565C0);
    case ShopStatus.expiringSoon:
      return const Color(0xFFEF6C00);
    case ShopStatus.expired:
      return const Color(0xFFC62828);
    case ShopStatus.blocked:
      return const Color(0xFF4E342E);
  }
}

class ShopStatusChip extends StatelessWidget {
  const ShopStatusChip(this.status, {super.key});

  final ShopStatus status;

  @override
  Widget build(BuildContext context) {
    final color = shopStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String prettyDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String relativeExpiry(Shop shop) {
  final days = shop.daysLeft;
  if (shop.isBlocked) return 'Paused by admin';
  if (days < 0) return 'Expired ${-days}d ago · ${prettyDate(shop.expiresAt)}';
  if (days == 0) return 'Expires today · ${prettyDate(shop.expiresAt)}';
  return 'Expires in ${days}d · ${prettyDate(shop.expiresAt)}';
}
