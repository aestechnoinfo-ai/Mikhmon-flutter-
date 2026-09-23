import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../core/utils/pdf_voucher_builder.dart';
import '../models/voucher.dart';
import '../widgets/responsive.dart';
import '../widgets/voucher_card.dart';

/// Aperçu + impression PDF d'une sélection de vouchers.
class VoucherPrintScreen extends StatefulWidget {
  final List<Voucher> vouchers;
  const VoucherPrintScreen({super.key, required this.vouchers});

  @override
  State<VoucherPrintScreen> createState() => _VoucherPrintScreenState();
}

class _VoucherPrintScreenState extends State<VoucherPrintScreen> {
  int _perPage = 6;
  bool _busy = false;

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final bytes = await buildVoucherPdf(
        vouchers: widget.vouchers,
        appTitle: 'Mikhmon Wifi',
        perPage: _perPage,
      );
      if (!mounted) return;
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: 'mikhmon-vouchers.pdf');
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
          case TargetPlatform.iOS:
            await Printing.sharePdf(bytes: bytes, filename: 'mikhmon-vouchers.pdf');
            break;
          default:
            await Printing.layoutPdf(
              onLayout: (_) async => bytes,
              name: 'mikhmon-vouchers.pdf',
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'impression : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Vouchers (${widget.vouchers.length})'),
        actions: [
          IconButton(
            tooltip: 'Imprimer',
            onPressed: _busy ? null : _print,
            icon: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: Responsive.pagePadding(context).copyWith(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.grid_view_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Tickets par page'),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 4, label: Text('4')),
                    ButtonSegment(value: 6, label: Text('6')),
                    ButtonSegment(value: 8, label: Text('8')),
                    ButtonSegment(value: 12, label: Text('12')),
                  ],
                  selected: {_perPage},
                  onSelectionChanged: (s) => setState(() => _perPage = s.first),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print),
                  label: _busy ? const Text('…') : const Text('Imprimer / PDF'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: Responsive.pagePadding(context),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols =
                        (constraints.maxWidth / 190).floor().clamp(1, 4).toInt();
                    final w = (constraints.maxWidth - (cols - 1) * 12) / cols;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final v in widget.vouchers)
                          Container(
                            width: w,
                            height: 210,
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: VoucherCard(
                              voucher: v,
                              showQr: true,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}