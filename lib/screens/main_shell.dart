import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/responsive.dart';
import 'billing_screen.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';
import 'monitor_screen.dart';
import 'profiles_screen.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';
import 'vouchers_screen.dart';

/// Coquille principale avec navigation responsive.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget builder;
  const _Destination(this.icon, this.selectedIcon, this.label, this.builder);
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _destinations = <_Destination>[
    _Destination(Icons.dashboard_outlined, Icons.dashboard, 'Tableau de bord',
        DashboardScreen()),
    _Destination(Icons.router_outlined, Icons.router, 'Serveurs', ServersScreen()),
    _Destination(Icons.speed_outlined, Icons.speed, 'Profils', ProfilesScreen()),
    _Destination(Icons.confirmation_number_outlined, Icons.confirmation_number,
        'Vouchers', VouchersScreen()),
    _Destination(Icons.list_alt_outlined, Icons.receipt_long, 'Billing',
        BillingScreen()),
    _Destination(Icons.monitor_heart_outlined, Icons.monitor_heart, 'Monitor',
        MonitorScreen()),
    _Destination(Icons.article_outlined, Icons.article, 'Logs', LogsScreen()),
    _Destination(Icons.settings_outlined, Icons.settings, 'Réglages',
        SettingsScreen()),
  ];

  Future<void> _connect(AppState app) async {
    if (app.status == AppStatus.connected) {
      await app.disconnect();
    } else {
      await app.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDesktop = Responsive.isDesktop(context);

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_destinations[_index].selectedIcon,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _destinations[_index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (Responsive.isWide(context)) ...[
              const SizedBox(width: 12),
              _serverChip(app),
            ],
          ],
        ),
        actions: [
          _ConnectionChip(app: app),
          PopupMenuButton<String>(
            tooltip: 'Compte',
            onSelected: (v) async {
              if (v == 'logout') await app.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'server',
                enabled: app.servers.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.lan_outlined),
                    SizedBox(width: 8),
                    Text('Choisir le serveur'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Déconnexion'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: app.errorMessage != null
            ? Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.error_outline),
                  title: Text(
                    app.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: app.clearError,
                  ),
                  onTap: () async {
                    app.clearError();
                    await _connect(app);
                  },
                ),
              )
            : null,
      ),
      body: IndexedStack(
        index: _index,
        children: [for (final d in _destinations) d.builder],
      ),
      floatingActionButton: isDesktop ? null : _serverSwitchFab(app),
    );

    if (!isDesktop) {
      return scaffold.copyWith(
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.wifi_tethering,
                  size: 34, color: Theme.of(context).colorScheme.primary),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                tooltip: 'Déconnexion',
                icon: const Icon(Icons.logout),
                onPressed: () => app.logout(),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: scaffold),
        ],
      ),
    );
  }

  Widget? _serverSwitchFab(AppState app) {
    if (app.servers.isEmpty) return null;
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ServersScreen(picking: true),
        ));
      },
      icon: const Icon(Icons.sync_alt),
      label: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('Serveur'),
      ),
    );
  }

  Widget _serverChip(AppState app) {
    final server = app.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            server?.name ?? 'Aucun serveur',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// Pastille de connexion dans l'AppBar.
class _ConnectionChip extends StatelessWidget {
  final AppState app;
  const _ConnectionChip({required this.app});

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (app.status) {
      AppStatus.connected => const Color(0xFF4CAF50),
      AppStatus.connecting => Colors.orange,
      AppStatus.error => scheme.error,
      _ => scheme.outline,
    };
  }

  String get _label => switch (app.status) {
        AppStatus.connected =>
          app.service?.connectedLabel ?? 'Connecté',
        AppStatus.connecting => 'Connexion…',
        AppStatus.error => 'Erreur',
        _ => 'Déconnecté',
      };

  @override
  Widget build(BuildContext context) {
    final busy = app.status == AppStatus.connecting;
    final color = _color(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: busy ? null : () => _toggle(context),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.circle, size: 12, color: color),
        label: Text(
          _label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    if (app.currentServer == null && app.servers.isNotEmpty) {
      await app.selectServer(app.servers.first.id);
    }
    if (app.status == AppStatus.connected) {
      await app.disconnect();
    } else {
      await app.connect();
    }
  }
}