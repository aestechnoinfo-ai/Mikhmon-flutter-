import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/remote_entities.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../widgets/responsive.dart';

/// Gestion du billing : users du hotspot du serveur courant.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with AutomaticKeepAliveClientMixin {
  final _billing = BillingProvider();
  BillingFilter _filter = BillingFilter.all;
  String _query = '';
  String? _lastServiceId;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AppState>().service;
    final sid = service == null ? null : service.server.id;
    if (service != null && sid != _lastServiceId) {
      _lastServiceId = sid;
      _billing.refresh(service);
    }
  }

  Future<void> _refresh() async {
    final service = context.read<AppState>().service;
    if (service != null) await _billing.refresh(service);
    if (mounted) setState(() {});
  }

  Future<void> _toggleDisable(RemoteHotspotUser u) async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() => _billing.loading = true);
    try {
      await service.setHotspotUserDisabled(u.id, !u.disabled);
      await context
          .read<AppState>()
          .log
          .action('User ${u.name} ${u.disabled ? 'activé' : 'désactivé'}');
    } catch (e) {
      _snack('Erreur : $e');
    }
    setState(() => _billing.loading = false);
    await _refresh();
  }

  Future<void> _delete(RemoteHotspotUser u) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le user ?'),
        content: Text(
            'Le user "${u.name}" (profil ${u.profile}) sera retiré du hotspot.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await service.deleteHotspotUser(u.id);
        await app.log.action('User ${u.name} supprimé');
      } catch (e) {
        _snack('Erreur : $e');
      }
      await _refresh();
    }
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
    final connected = app.service != null && app.status == AppStatus.connected;

    final filtered = _billing
        .filter(_filter)
        .where((u) =>
            _query.isEmpty ||
            u.name.toLowerCase().contains(_query.toLowerCase()) ||
            u.comment.toLowerCase().contains(_query.toLowerCase()) ||
            u.profile.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        _filtersBar(app, connected),
        const Divider(height: 1),
        if (!connected)
          Expanded(
            child: Center(
              child: ElevatedButton.icon(
                onPressed: app.connect,
                icon: const Icon(Icons.link),
                label: const Text('Connecter pour charger le billing'),
              ),
            ),
          )
        else
          Expanded(
            child: _billing.loading && filtered.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _userList(filtered),
          ),
      ],
    );
  }

  Widget _filtersBar(AppState app, bool connected) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: Responsive.pagePadding(context).copyWith(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher user / commentaire',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Actualiser',
                onPressed: _billing.loading ? null : _refresh,
                icon: _billing.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in BillingFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: f == BillingFilter.online
                          ? Icon(Icons.circle, size: 12, color: scheme.primary)
                          : null,
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userList(List<RemoteHotspotUser> list) {
    if (list.isEmpty) {
      return const Center(child: Text('Aucun user dans cette catégorie.'));
    }
    final online = _billing.onlineUserNames;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(context),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final u = list[i];
          final isOnline = online.contains(u.name);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isOnline
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListTile(
              leading: Icon(
                u.disabled
                    ? Icons.block
                    : isOnline
                        ? Icons.circle
                        : Icons.person_outline,
                color: u.disabled
                    ? Theme.of(context).colorScheme.error
                    : isOnline
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: Text(u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${u.profile} • ${u.limitUptimeLabel}${u.bytesLabel.isNotEmpty && u.limitBytesTotal > 0 ? ' • ${u.bytesLabel}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: u.comment.isNotEmpty
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        u.comment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                      ),
                    )
                  : null,
              onTap: () => _showDetail(u),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(RemoteHotspotUser u) {
    final online = _billing.onlineUserNames.contains(u.name);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (online)
                    const Chip(
                      label: Text('En ligne'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (u.disabled)
                    const Chip(
                      label: Text('Désactivé'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _row('Mot de passe', u.password),
              _row('Profil', u.profile),
              _row('Commentaire', u.comment.isEmpty ? '—' : u.comment),
              _row('Durée limitée', u.limitUptimeLabel),
              _row('Limite octets', u.limitBytesTotal > 0 ? u.bytesLabel : 'Illimitée'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _toggleDisable(u);
                      },
                      icon: Icon(u.disabled
                          ? Icons.check_circle_outline
                          : Icons.block),
                      label: Text(u.disabled ? 'Activer' : 'Désactiver'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(ctx).colorScheme.error,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _delete(u);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(v, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}