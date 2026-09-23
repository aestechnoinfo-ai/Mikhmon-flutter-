import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_log.dart';
import '../models/remote_entities.dart';
import '../state/app_state.dart';
import '../widgets/responsive.dart';

/// Journal : activité locale + logs système du routeur.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen>
    with AutomaticKeepAliveClientMixin {
  int _tab = 0;
  List<SystemLogEntry> _routerLogs = [];
  bool _loadingRouterLogs = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadRouterLogs() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() => _loadingRouterLogs = true);
    try {
      _routerLogs = await service.systemLogs();
      // On garde un maximum raisonnable.
      _routerLogs = _routerLogs.length > 200
          ? _routerLogs.sublist(_routerLogs.length - 200)
          : _routerLogs;
    } catch (e) {
      _routerLogs = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de lecture des logs : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRouterLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();
    final logs = app.storage.logs;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: Responsive.pagePadding(context).copyWith(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Local'),
                      icon: Icon(Icons.history, size: 18),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Routeur'),
                      icon: Icon(Icons.router, size: 18),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) {
                    setState(() => _tab = s.first);
                    if (s.first == 1 && _routerLogs.isEmpty) {
                      _loadRouterLogs();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (_tab == 0)
                IconButton(
                  tooltip: 'Vider',
                  onPressed: () async {
                    await app.storage.clearLogs();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                )
              else
                IconButton.filledTonal(
                  tooltip: 'Recharger',
                  onPressed: _loadRouterLogs,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _tab == 0
              ? _localLogs(logs)
              : _routerLogsView(app.service != null),
        ),
      ],
    );
  }

  Widget _localLogs(List<AppLog> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 10),
              const Text('Aucun événement local pour le moment.'),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: Responsive.pagePadding(context),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final log = logs[i];
        final icon = switch (log.type) {
          LogType.login => Icons.login,
          LogType.action => Icons.bolt,
          LogType.error => Icons.error_outline,
          LogType.system => Icons.memory,
          LogType.info => Icons.info_outline,
        };
        final color = switch (log.type) {
          LogType.error => Theme.of(context).colorScheme.error,
          LogType.login => Theme.of(context).colorScheme.primary,
          _ => Theme.of(context).colorScheme.onSurfaceVariant,
        };
        return ListTile(
          dense: true,
          leading: Icon(icon, size: 20, color: color),
          title: Text(log.message, style: Theme.of(context).textTheme.bodySmall),
          subtitle: Text(
            _fmt(log.createdAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }

  Widget _routerLogsView(bool connected) {
    if (!connected) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: context.read<AppState>().connect,
          icon: const Icon(Icons.link),
          label: const Text('Connecter pour lire les logs du routeur'),
        ),
      );
    }
    if (_loadingRouterLogs && _routerLogs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_routerLogs.isEmpty) {
      return const Center(child: Text('Aucun log système disponible.'));
    }
    return ListView.separated(
      padding: Responsive.pagePadding(context),
      itemCount: _routerLogs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = _routerLogs[_routerLogs.length - 1 - i];
        return ListTile(
          dense: true,
          leading: Icon(
            e.topics.contains('error')
                ? Icons.error_outline
                : Icons.article_outlined,
            size: 18,
            color: e.topics.contains('error')
                ? Theme.of(context).colorScheme.error
                : null,
          ),
          title: Text(e.message, style: Theme.of(context).textTheme.bodySmall),
          subtitle: Text(
            '${e.time} • ${e.topics}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }

  String _fmt(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m:$s';
  }
}