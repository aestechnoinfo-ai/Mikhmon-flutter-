import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/formatters.dart';
import '../models/remote_entities.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../widgets/responsive.dart';

/// Monitoring des sessions hotspot actives.
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with AutomaticKeepAliveClientMixin {
  final _monitor = MonitorProvider();
  Duration _interval = const Duration(seconds: 5);
  String? _lastServiceId;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _monitor.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AppState>().service;
    final sid = service == null ? null : service.server.id;
    if (service != null && sid != _lastServiceId) {
      _lastServiceId = sid;
      if (_monitor.running) {
        _monitor.start(service, period: _interval);
      } else {
        _monitor.refresh(service);
      }
    }
  }

  void _toggle(AppState app) {
    final service = app.service;
    if (service == null) return;
    if (_monitor.running) {
      _monitor.stop();
    } else {
      _monitor.start(service, period: _interval);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();
    final connected = app.service != null && app.status == AppStatus.connected;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: Responsive.pagePadding(context).copyWith(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (connected ? scheme.primary : scheme.outline)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _monitor.running
                              ? Icons.radar
                              : Icons.monitor_heart_outlined,
                          size: 16,
                          color:
                              connected ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_monitor.onlineCount} session(s)',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (_monitor.running) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<Duration>(
                    value: _interval,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: Duration(seconds: 2),
                        child: Text('2 s'),
                      ),
                      DropdownMenuItem(
                        value: Duration(seconds: 5),
                        child: Text('5 s'),
                      ),
                      DropdownMenuItem(
                        value: Duration(seconds: 15),
                        child: Text('15 s'),
                      ),
                      DropdownMenuItem(
                        value: Duration(minutes: 1),
                        child: Text('1 min'),
                      ),
                    ],
                    onChanged: (d) {
                      if (d == null) return;
                      setState(() => _interval = d);
                      final service = app.service;
                      if (service != null && _monitor.running) {
                        _monitor.start(service, period: d);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: connected ? () => _toggle(app) : null,
                    icon: Icon(_monitor.running
                        ? Icons.stop
                        : Icons.play_arrow),
                    label: Text(_monitor.running ? 'Arrêter' : 'Surveiller'),
                  ),
                ],
              ),
              if (!connected)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const Text(
                          'Connectez-vous au routeur pour surveiller les sessions.'),
                      TextButton.icon(
                        onPressed: app.connect,
                        icon: const Icon(Icons.link),
                        label: const Text('Connecter'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: connected ? _buildList() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildList() {
    final sessions = _monitor.sessions;
    if (_monitor.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_monitor.error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_monitor.loading && sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 10),
              Text(
                _monitor.running
                    ? 'Aucune session active pour le moment.'
                    : 'Lancez la surveillance pour voir les clients connectés.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        final service = context.read<AppState>().service;
        if (service != null) await _monitor.refresh(service);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(context),
        itemCount: sessions.length,
        itemBuilder: (context, i) => _SessionTile(session: sessions[i]),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ActiveSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(session.user,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${session.address}  •  ${session.macAddress}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.sessionUptimeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '▼ ${Formatters.bytesReadable(int.tryParse(session.bytesIn) ?? 0)}'
                  ' ▲ ${Formatters.bytesReadable(int.tryParse(session.bytesOut) ?? 0)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}