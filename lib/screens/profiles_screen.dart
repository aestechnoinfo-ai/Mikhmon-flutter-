import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/mikrotik/mikrotik_service.dart';
import '../models/hotspot_profile.dart';
import '../models/remote_entities.dart';
import '../models/router_server.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../widgets/responsive.dart';
import 'profile_form_screen.dart';

/// Profils : miroir local + états sur le routeur.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen>
    with AutomaticKeepAliveClientMixin {
  final _prov = ProfilesProvider();
  int _tab = 0;
  bool _pushing = false;
  String? _pushError;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _prov.dispose();
    super.dispose();
  }

  RouterServer? get _server => context.read<AppState>().currentServer;

  List<HotspotProfile> _local() =>
      context.read<AppState>().storage.profilesForServer(_server?.id);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AppState>().service;
    if (service != null) {
      _prov.loadRemote(service);
    }
  }

  void _reload() {
    setState(() {});
    final service = context.read<AppState>().service;
    if (service != null) _prov.loadRemote(service);
  }

  Future<void> _pushToRouter(HotspotProfile p) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) {
      _snack('Connectez-vous d’abord au routeur.');
      return;
    }
    setState(() {
      _pushing = true;
      _pushError = null;
    });
    try {
      final rate = MikrotikService.formatRateLimit(p.downloadKbps, p.uploadKbps);
      final exists = await service.findHotspotProfileByName(p.name);
      if (exists == null) {
        await service.createHotspotProfile(name: p.name, rateLimit: rate, sharedUsers: p.sharedUsers);
        await app.log.action('Profil "${p.name}" poussé vers le routeur', serverId: _server?.id);
      } else {
        await service.set('ip/hotspot/profile', {
          'name': p.name,
          'rate-limit': rate,
          if (p.sharedUsers > 0) 'shared-users': '${p.sharedUsers}',
        }, id: exists.id);
        await app.log.action('Profil "${p.name}" mis à jour sur le routeur', serverId: _server?.id);
      }
      await app.storage.upsertProfile(p.copyWith(synced: true));
      _snack('Profil "${p.name}" synchronisé sur le hotspot.');
    } catch (e) {
      setState(() => _pushError = e.toString());
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
    _reload();
  }

  Future<void> _deleteFromRouter(RemoteHotspotProfile rp) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    try {
      await service.deleteHotspotProfile(rp.name);
      await app.log.action('Profil "${rp.name}" supprimé du routeur', serverId: _server?.id);
      _snack('Profil "${rp.name}" supprimé du routeur.');
    } catch (e) {
      _snack('Erreur : $e');
    }
    _reload();
  }

  Future<void> _editLocal(HotspotProfile? p) async {
    final saved = await Navigator.of(context).push<HotspotProfile>(
      MaterialPageRoute(builder: (_) => ProfileFormScreen(profile: p)),
    );
    if (saved != null && mounted) {
      await context.read<AppState>().storage.upsertProfile(saved.copyWith(serverId: _server?.id));
      _snack(p == null ? 'Profil créé.' : 'Profil modifié.');
      _reload();
    }
  }

  Future<void> _deleteLocal(HotspotProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le profil ?'),
        content: Text('Le profil "${p.name}" sera retiré de la liste locale.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().storage.removeProfile(p.id);
      _reload();
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
    final local = _local();
    _prov.cacheLocal(local);

    final connected = app.service != null && app.status == AppStatus.connected;

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
                      label: Text('Locaux'),
                      icon: Icon(Icons.storage_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Routeur'),
                      icon: Icon(Icons.router, size: 18),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Actualiser',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: 'Nouveau profil',
                onPressed: () => _editLocal(null),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (_pushError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline),
                title: Text(_pushError!, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _pushError = null),
                ),
              ),
            ),
          ),
        Expanded(
          child: _tab == 0
              ? _buildLocal(context, local, connected)
              : _buildRemote(app),
        ),
      ],
    );
  }

  Widget _buildLocal(BuildContext context, List<HotspotProfile> local, bool connected) {
    if (local.isEmpty) {
      return _EmptyProfiles(onAdd: () => _editLocal(null));
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(context),
        itemCount: local.length,
        itemBuilder: (context, i) {
          final p = local[i];
          return _ProfileCard(
            profile: p,
            actions: [
              if (connected)
                IconButton(
                  tooltip: 'Envoyer vers le routeur',
                  onPressed: _pushing ? null : () => _pushToRouter(p),
                  icon: const Icon(Icons.cloud_upload_outlined),
                ),
              IconButton(
                tooltip: 'Modifier',
                onPressed: () => _editLocal(p),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer',
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _deleteLocal(p),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRemote(AppState app) {
    final list = _prov.remoteProfiles;
    final connected = app.service != null && app.status == AppStatus.connected;
    if (!connected) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: app.connect,
          icon: const Icon(Icons.link),
          label: const Text('Connecter pour voir le routeur'),
        ),
      );
    }
    if (_prov.loadingRemote && list.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return _EmptyProfiles(onAdd: () {});
    }
    return RefreshIndicator(
      onRefresh: () async {
        if (app.service != null) await _prov.loadRemote(app.service!);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(context),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final rp = list[i];
          return ListTile(
            leading: const Icon(Icons.speed),
            title: Text(rp.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              'Débit : ${rp.rateLimit.isEmpty ? 'Illimité' : rp.rateLimit}'
              '  •  Partage : ${rp.sharedUsers.isEmpty ? '∞' : rp.sharedUsers}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Supprimer du routeur',
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteFromRouter(rp),
            ),
            onTap: () => _showRemoteDetail(rp),
          );
        },
      ),
    );
  }

  void _showRemoteDetail(RemoteHotspotProfile rp) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rp.name, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _row(ctx, 'Rate limit', rp.rateLimit.isEmpty ? 'Illimité' : rp.rateLimit),
            _row(ctx, 'Validité', rp.validity.isEmpty ? '—' : rp.validity),
            _row(ctx, 'Users partagés', rp.sharedUsers.isEmpty ? '∞' : rp.sharedUsers),
            _row(ctx, 'MAC cookie', rp.macCookie.isEmpty ? '—' : rp.macCookie),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext ctx, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(v, style: Theme.of(ctx).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final HotspotProfile profile;
  final List<Widget> actions;

  const _ProfileCard({required this.profile, required this.actions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.speed, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (profile.synced) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.cloud_done, size: 15, color: scheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${profile.price.toStringAsFixed(2).replaceAll('.', ',')} • '
                      '${profile.validityLabel} • ${profile.rateLimitLabel}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (profile.comment.isNotEmpty)
                    Text(
                      profile.comment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _EmptyProfiles extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyProfiles({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed_outlined,
                size: 60, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Aucun profil local'),
            const SizedBox(height: 8),
            const Text(
              'Créez des profils (durée, débit, prix) puis envoyez-les '
              'au hotspot du routeur.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Créer un profil'),
            ),
          ],
        ),
      ),
    );
  }
}