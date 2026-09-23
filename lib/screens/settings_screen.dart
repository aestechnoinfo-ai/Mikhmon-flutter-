import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Réglages du panel local.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currencyCtrl = TextEditingController();
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _currencyCtrl.text = context.read<AppState>().settings.currencySymbol;
  }

  @override
  void dispose() {
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppState app, AppSettings next) async {
    await app.saveSettings(next);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Réglages enregistrés.')));
    }
  }

  Future<void> _changePassword(AppState app) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Nouveau mot de passe'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (next.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe vide.')));
                return;
              }
              if (next.text != confirm.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Les mots de passe ne correspondent pas.')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Changer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await app.auth.changePassword(
            current: current.text, newPass: next.text);
        await app.log.action('Mot de passe administrateur modifié');
        if (mounted) _snack('Mot de passe modifié.');
      } catch (e) {
        if (mounted) _snack('Erreur : $e');
      }
    }
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('Administrateur'),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Changer le mot de passe'),
          subtitle: const Text("Sécurisez l'accès au panel"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _changePassword(app),
        ),
        const Divider(),
        _section('Identité & transport'),
        SwitchListTile(
          title: const Text('Rester connecté'),
          subtitle: const Text('Ne pas demander le login au démarrage'),
          value: s.keepSessionOpen,
          onChanged: (v) => _save(
              app,
              s.copyWith(keepSessionOpen: v)),
        ),
        ListTile(
          leading: const Icon(Icons.currency_exchange),
          title: const Text('Symbole de devise'),
          subtitle: Text(s.currencySymbol),
          trailing: SizedBox(
            width: 70,
            child: TextField(
              controller: _currencyCtrl,
              textAlign: TextAlign.center,
              onSubmitted: (v) => _save(app, s.copyWith(currencySymbol: v)),
            ),
          ),
          onTap: null,
        ),
        DropdownButtonFormField<String>(
          initialValue: app.servers.any((s) => s.id == s.defaultServerId)
              ? s.defaultServerId
              : null,
          decoration: const InputDecoration(
            labelText: 'Serveur par défaut',
            prefixIcon: Icon(Icons.router_outlined),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('— Aucun —')),
            for (final srv in app.servers)
              DropdownMenuItem(value: srv.id, child: Text(srv.name)),
          ],
          onChanged: (v) => _save(app, s.copyWith(defaultServerId: v ?? '')),
        ),
        const Divider(),
        _section('Vouchers'),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: const Text('Préfixe du nom'),
          subtitle: Text(s.voucherPrefix.isEmpty
              ? '(vide)'
              : 'Les codes commenceront par "${s.voucherPrefix}…"'),
          trailing: SizedBox(
            width: 120,
            child: TextField(
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'ex: wifi-',
              ),
              onChanged: (v) {
                _save(
                    app,
                    s.copyWith(
                        voucherPrefix: v.trim().replaceAll(RegExp(r'\s'), '')));
              },
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Majuscules'),
          subtitle: const Text('A-Z dans le nom utilisateur'),
          value: s.voucherUppercase,
          onChanged: (v) => _save(app, s.copyWith(voucherUppercase: v)),
        ),
        SwitchListTile(
          title: const Text('Chiffres'),
          subtitle: const Text('0-9 dans le nom utilisateur'),
          value: s.voucherDigits,
          onChanged: (v) => _save(app, s.copyWith(voucherDigits: v)),
        ),
        ListTile(
          leading: const Icon(Icons.numbers),
          title: const Text('Longueur du code'),
          subtitle: Text('${s.voucherLength} caractères aléatoires'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: s.voucherLength > 3
                    ? () => _save(
                        app, s.copyWith(voucherLength: s.voucherLength - 1))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${s.voucherLength}'),
              IconButton(
                onPressed: s.voucherLength < 12
                    ? () => _save(
                        app, s.copyWith(voucherLength: s.voucherLength + 1))
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Mot de passe aléatoire'),
          subtitle: const Text('Désactivé = mot de passe fixe ci-dessous'),
          value: s.voucherPasswordGenerated,
          onChanged: (v) => _save(app, s.copyWith(voucherPasswordGenerated: v)),
        ),
        if (!s.voucherPasswordGenerated)
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Mot de passe fixe'),
            trailing: SizedBox(
              width: 140,
              child: TextField(
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: 'ex: 123456'),
                onChanged: (v) => _save(app, s.copyWith(voucherFixedPassword: v)),
              ),
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.shuffle),
            title: const Text('Longueur du mot de passe'),
            subtitle: Text('${s.voucherPasswordLength} caractères'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: s.voucherPasswordLength > 3
                      ? () => _save(app,
                          s.copyWith(voucherPasswordLength: s.voucherPasswordLength - 1))
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${s.voucherPasswordLength}'),
                IconButton(
                  onPressed: s.voucherPasswordLength < 12
                      ? () => _save(app,
                          s.copyWith(voucherPasswordLength: s.voucherPasswordLength + 1))
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        const Divider(),
        _section('Thème'),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) => SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Système'),
                icon: Icon(Icons.brightness_auto, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Clair'),
                icon: Icon(Icons.light_mode, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Sombre'),
                icon: Icon(Icons.dark_mode, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (m) => themeController.value = m.first,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        _section('Données'),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text("Vider l'historique des vouchers"),
          subtitle: const Text('Supprime les enregistrements locaux uniquement'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Vider l'historique ?"),
                content: const Text(
                    'Les vouchers déjà générés resteront actifs sur le routeur.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Vider'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await app.storage.clearVouchers();
              _snack('Historique vidé.');
            }
          },
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          t,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}