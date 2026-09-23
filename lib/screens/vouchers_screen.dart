import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/hotspot_profile.dart';
import '../models/voucher.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../widgets/responsive.dart';
import '../widgets/voucher_card.dart';
import 'voucher_print_screen.dart';

/// Écran de génération et historique des vouchers.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen>
    with AutomaticKeepAliveClientMixin {
  final _countCtrl = TextEditingController(text: '20');
  String? _profileId;
  List<Voucher> _lastBatch = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  List<HotspotProfile> _profiles(AppState app) {
    final sid = app.currentServer?.id;
    return app.storage.profilesForServer(sid);
  }

  HotspotProfile? _selectedProfile(AppState app) {
    final list = _profiles(app);
    if (list.isEmpty) return null;
    if (_profileId != null) {
      for (final p in list) {
        if (p.id == _profileId) return p;
      }
    }
    return list.first;
  }

  Future<void> _generate(AppState app) async {
    final provider = context.read<VouchersProvider>();
    final profile = _selectedProfile(app);
    final service = app.service;
    final server = app.currentServer;
    if (profile == null || service == null || server == null) {
      _snack('Ajoutez un profil et connectez-vous au routeur.');
      return;
    }
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (count <= 0 || count > 1000) {
      _snack('Quantité invalide (1-1000).');
      return;
    }
    await provider.generate(
      server: server,
      profile: profile,
      count: count,
      settings: app.settings,
      service: service,
    );
    final result = provider.lastResult;
    final history = context.read<VoucherHistory>();
    history.reload(app.storage.vouchers);
    if (!mounted || result == null) return;
    if (result.ok && result.vouchers.isNotEmpty) {
      setState(() => _lastBatch = result.vouchers);
      _snack(result.message);
    } else {
      _snack(result.message);
    }
  }

  Future<void> _openPrint(List<Voucher> vouchers) async {
    if (vouchers.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoucherPrintScreen(vouchers: vouchers),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();
    final shepherd = context.watch<VouchersProvider>();
    final history = context.watch<VoucherHistory>();
    final profiles = _profiles(app);
    final selected = _selectedProfile(app);
    final connected = app.service != null && app.status == AppStatus.connected;

    return ListView(
      padding: Responsive.pagePadding(context),
      children: [
        _generationCard(
            context, app, shepherd, profiles, selected, connected),
        const SizedBox(height: 20),
        if (shepherd.generating)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _progressCard(shepherd),
          ),
        if (_lastBatch.isNotEmpty) ...[
          _sectionHeader(
            'Dernier lot (${_lastBatch.length})',
            trailing: TextButton.icon(
              onPressed: () => _openPrint(_lastBatch),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimer / PDF'),
            ),
          ),
          const SizedBox(height: 10),
          _gridPreview(_lastBatch),
          const SizedBox(height: 8),
        ],
        if (history.items.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('Historique (${history.items.length})',
              trailing: TextButton.icon(
                onPressed: () => _openPrint(history.items),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Tout imprimer'),
              )),
          const SizedBox(height: 6),
          _historyList(history.items),
        ] else if (_lastBatch.isEmpty)
          _emptyHint(profiles.isEmpty ? 'profile' : 'voucher'),
      ],
    );
  }

  Widget _generationCard(
    BuildContext context,
    AppState app,
    VouchersProvider provider,
    List<HotspotProfile> profiles,
    HotspotProfile? selected,
    bool connected,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Générer des vouchers',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Format : ${_formatSummary(app.settings.voucherPrefix, app.settings.voucherLength, app.settings.voucherUppercase, app.settings.voucherDigits)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selected?.id,
              decoration: const InputDecoration(
                labelText: 'Profil hotspot',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              items: [
                for (final p in profiles)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.name} — ${p.price.toStringAsFixed(2).replaceAll('.', ',')} • ${p.validityLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: profiles.isEmpty
                  ? null
                  : (v) => setState(() => _profileId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantité',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (provider.generating || !connected || profiles.isEmpty)
                  ? null
                  : () => _generate(app),
              icon: provider.generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(provider.generating
                  ? 'Génération en cours…'
                  : 'Générer sur le hotspot'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(VouchersProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Création des users hotspot… (${provider.done}/${provider.total})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: provider.progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSummary(String prefix, int len, bool upper, bool digits) {
    final charset = [
      if (upper) 'A-Z' else 'a-z',
      if (digits) '0-9',
    ].join('+');
    return '#${prefix.isEmpty ? '' : '"${prefix}"-'}$charset × $len';
  }

  Widget _sectionHeader(String title, {required Widget trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Flexible(child: trailing),
      ],
    );
  }

  Widget _gridPreview(List<Voucher> vouchers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 170).floor().clamp(2, 6).toInt();
        final w = (constraints.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < math.min(vouchers.length, 2 * cols); i++)
              SizedBox(
                width: w,
                height: 200,
                child: VoucherCard(
                  voucher: vouchers[i],
                  showQr: true,
                  compact: false,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _historyList(List<Voucher> items) {
    final recent = items.length > 60 ? items.sublist(items.length - 60) : items;
    return Column(
      children: [
        for (var i = recent.length - 1; i >= 0; i--)
          ListTile(
            dense: true,
            leading: const Icon(Icons.credit_card),
            title: Text(recent[i].username,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${recent[i].profileName} • ${recent[i].validityLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '${recent[i].price.toStringAsFixed(0)} ${recent[i].currencySymbol}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _emptyHint(String what) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Icon(
          what == 'profile'
              ? Icons.speed_outlined
              : Icons.confirmation_number_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}