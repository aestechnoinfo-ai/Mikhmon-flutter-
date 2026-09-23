import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/voucher.dart';

/// Carte de voucher réutilisable (aperçu écran, sans débordement).
class VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final bool showQr;
  final bool compact;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.showQr = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Liseré supérieur coloré
          Container(height: 6, color: accent, width: double.infinity),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!compact)
                    Text(
                      voucher.profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      voucher.username,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                  if (!compact && showQr) ...[
                    const SizedBox(height: 6),
                    QrImageView(
                      data: voucher.code,
                      size: 72,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      voucher.validityLabel,
                      maxLines: 1,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: accent.withValues(alpha: .10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    voucher.password,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${voucher.price.toStringAsFixed(0)} ${voucher.currencySymbol}',
                  maxLines: 1,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}