import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/router_server.dart';
import '../state/app_state.dart';
import '../widgets/responsive.dart';
import 'server_form_screen.dart';

/// Liste des serveurs (routeurs) gérés.
class ServersScreen extends StatefulWidget {
  final bool picking;
  const ServersScreen({super.key, this.picking = false});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  Future<void> _edit(AppState app, RouterServer? server) async {
    final saved = await Navigator.of(context).push<RouterServer>(
      MaterialPageRoute(
        builder: (_) => ServerFormScreen(server: server),
      ),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(server == null
            ? 'Serveur "${saved.name}" ajouté.'
            : 'Serveur "${saved.name}" mis à jour.')),
      );
      if (app.status == AppStatus.connected &&
          app.current?.id == saved.id) {
        await app.connect();
      }
    }
  }

  Future<void> _delete(AppState app, RouterServer s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce serveur ?'),
        content: Text(
            'Le serveur "${s.name}" (${s.host}) sera retiré de la liste.\n'
            'Les profils associés seront aussi supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await app.deleteServer(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final servers = app.servers;

    return Scaffold(
      body: servers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.router,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text('Aucun routeur configuré'),
                    const SizedBox(height: 8),
                    const Text(
                      'Ajoutez votre premier serveur MikroTik pour commencer.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _edit(app, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un serveur'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: Responsive.pagePadding(context),
              itemCount: servers.length,
              itemBuilder: (context, i) {
                final s = servers[i];
                return _ServerTile(
                  server: s,
                  selected: app.current?.id == s.id,
                  picking: widget.picking,
                  onEdit: () => _edit(app, s),
                  onDelete: () => _delete(app, s),
                  onSelect: () {
                    if (widget.picking) {
                      Navigator.of(context).pop(s);
                    } else {
                      app.selectServer(s.id);
                    }
                  },
                );
              },
            ),
      floatingActionButton: servers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(app, null),
              icon: const Icon(Icons.add),
              label: const Text('Serveur'),
            ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final RouterServer server;
  final bool selected;
  final bool picking;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _ServerTile({
    required this.server,
    required this.selected,
    required this.picking,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transportLabel = switch (server.transport) {
      TransportChoice.api => 'API RouterOS',
      TransportChoice.rest => 'REST API',
      _ => 'Auto',
    };
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant),
      ),
      color: selected ? scheme.primaryContainer.withValues(alpha: .35) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  server.enabled ? Icons.router : Icons.router_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle,
                              color: scheme.primary, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${server.host}  •  $transportLabel  •  hotspot:${server.hotspotName}',
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
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Supprimer',
                color: scheme.error,
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}