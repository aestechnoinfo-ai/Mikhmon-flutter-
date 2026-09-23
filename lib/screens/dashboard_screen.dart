import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/mikrotik/mikrotik_service.dart';
import '../models/remote_entities.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/stat_card.dart';

/// Tableau de bord : infos routeur + statistiques.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final _metrics = MetricsProvider();
  String? _lastServiceId;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  Future<void> _refresh(AppState app) async {
    final s = app.service;
    if (s == null) return;
    setState(() => _busy = true);
    await _metrics.refresh(s);
    if (mounted) setState(() => _busy = false);
  }

  void _maybeRefresh(AppState app) {
    final s = app.service;
    final sid = s == null ? null : '${s.server.id}';
    if (s != null && sid != _lastServiceId) {
      _lastServiceId = sid;
      _refresh(app);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();
    _maybeRefresh(app);

    final connected = app.service != null && app.status == AppStatus.connected;

    return RefreshIndicator(
      onRefresh: () => _refresh(app),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(context),
        children: [
          _header(app, connected),
          if (!connected)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.link_off,
                title: 'Non connecté',
                subtitle:
                    'Sélectionnez un serveur puis connectez-vous pour voir les statistiques du routeur.',
                action: FilledButton.icon(
                  onPressed: () => app.connect(),
                  icon: const Icon(Icons.link),
                  label: const Text('Se connecter au routeur'),
                ),
              ),
            )
          else
            ..._content(app),
        ],
      ),
    );
  }

  Widget _header(AppState app, bool connected) {
    final m = _metrics.metrics;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m?.identity.isNotEmpty == true
                    ? m!.identity
                    : (app.currentServer?.name ?? 'Tableau de bord'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (m != null)
                Text(
                  '${m.boardName} • RouterOS ${m.version} • ${m.architecture}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Actualiser',
          onPressed: _busy ? null : () => _refresh(app),
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
      ],
    );
  }

  List<Widget> _content(AppState app) {
    final m = _metrics.metrics;
    final cols =
        Responsive.gridColumns(context, minTile: 200, max: 4);

    final double gap = cols <= 2 ? 12 : 16;

    final cards = <Widget>[
      StatCard(
        icon: Icons.access_time,
        label: 'Uptime',
        value: m?.uptime.inHours > 0
            ? '${m!.uptime.inDays} j ${m.uptime.inHours % 24} h'
            : '—',
        subtitle: 'Depuis le démarrage',
        onTap: null,
      ),
      StatCard(
        icon: Icons.speed,
        label: 'Charge CPU',
        value: m != null ? m.cpuLabel : '—',
        subtitle: m != null ? 'Échantillon actuel' : null,
        color: Theme.of(context).colorScheme.error,
      ),
      StatCard(
        icon: Icons.memory,
        label: 'Mémoire',
        value: m != null ? m.memLabel : '—',
        subtitle: m != null ? '${_memPct(m).toStringAsFixed(0)} % utilisée' : null,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      StatCard(
        icon: Icons.storage,
        label: 'Disque',
        value: m != null ? m.hddLabel : '—',
        subtitle: m != null ? '${m.hddUsage.toStringAsFixed(0)} %' : null,
      ),
      StatCard(
        icon: Icons.group_outlined,
        label: 'Users hotspot',
        value: _metrics.totalUsers >= 0 ? '${_metrics.totalUsers}' : '…',
        subtitle: 'Total créés',
        color: Theme.of(context).colorScheme.secondary,
      ),
      StatCard(
        icon: Icons.monitor_heart_outlined,
        label: 'Sessions actives',
        value: _metrics.activeSessions >= 0 ? '${_metrics.activeSessions}' : '…',
        subtitle: 'En ligne maintenant',
        color: const Color(0xFF43B02A),
      ),
      _usageBar('Mémoire', _memPct(m), m?.freeMemory, m?.totalMemory),
      _usageBar('Disque', m?.hddUsage ?? 0, m?.freeHdd, m?.totalHdd),
    ];

    return [
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final cw = (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: 12,
            children: [
              for (final c in cards)
                SizedBox(width: cw, child: c),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _metaCard(m, _metrics),
    ];
  }

  static double _memPct(RouterMetrics? m) =>
      m == null ? 0 : m.memoryUsage.clamp(0, 100).toDouble();

  Widget _usageBar(String label, double pct, int? free, int? total) {
    final schemeTheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
                color: pct > 85
                    ? schemeTheme.error
                    : schemeTheme.primary,
                backgroundColor: schemeTheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${pct.toStringAsFixed(0)} %',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: schemeTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaCard(RouterMetrics? m, MetricsProvider prov) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      ('Version RouterOS', m?.version ?? '—'),
      ('Identité', m?.identity ?? '—'),
      ('Date de build', m?.buildTime ?? '—'),
      ('Transport', prov.error != null ? prov.error! : 'OK'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(k,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: Text(
                        v,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}