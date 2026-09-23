import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/mikrotik/mikrotik_service.dart';
import '../core/utils/uid.dart';
import '../models/router_server.dart';
import '../state/app_state.dart';

/// Formulaire d'ajout / édition d'un serveur MikroTik.
class ServerFormScreen extends StatefulWidget {
  final RouterServer? server;
  const ServerFormScreen({super.key, this.server});

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _hotspot;
  late final TextEditingController _apiPort;
  late final TextEditingController _restPort;
  late final TextEditingController _apiSslPort;
  late final TextEditingController _restSslPort;

  late TransportChoice _transport;
  late ApiLoginMethod _loginMethod;
  bool _useApiSsl = false;
  bool _useRestSsl = true;
  bool _enabled = true;
  bool _busy = false;

  bool get _isEdit => widget.server != null;

  @override
  void initState() {
    super.initState();
    final s = widget.server;
    _name = TextEditingController(text: s?.name ?? '');
    _host = TextEditingController(text: s?.host ?? '192.168.88.1');
    _user = TextEditingController(text: s?.username ?? 'admin');
    _pass = TextEditingController(text: s?.password ?? '');
    _hotspot = TextEditingController(text: s?.hotspotName ?? 'hotspot1');
    _apiPort = TextEditingController(text: '${s?.apiPort ?? AppConstants.defaultApiPort}');
    _restPort = TextEditingController(text: '${s?.restPort ?? AppConstants.defaultRestPort}');
    _apiSslPort = TextEditingController(text: '${s?.apiSslPort ?? AppConstants.defaultApiSslPort}');
    _restSslPort = TextEditingController(text: '${s?.restSslPort ?? AppConstants.defaultRestSslPort}');
    _transport = s?.transport ?? TransportChoice.auto;
    _loginMethod = s?.loginMethod ?? ApiLoginMethod.auto;
    _useApiSsl = s?.useApiSsl ?? false;
    _useRestSsl = s?.useRestSsl ?? true;
    _enabled = s?.enabled ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _host, _user, _pass, _hotspot, _apiPort, _restPort, _apiSslPort, _restSslPort
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  RouterServer _buildServer() {
    final base = widget.server;
    return RouterServer(
      id: base?.id ?? generateUid(),
      name: _name.text.trim(),
      host: _host.text.trim(),
      apiPort: int.tryParse(_apiPort.text) ?? AppConstants.defaultApiPort,
      apiSslPort: int.tryParse(_apiSslPort.text) ?? AppConstants.defaultApiSslPort,
      restPort: int.tryParse(_restPort.text) ?? AppConstants.defaultRestPort,
      restSslPort: int.tryParse(_restSslPort.text) ?? AppConstants.defaultRestSslPort,
      useApiSsl: _useApiSsl,
      useRestSsl: _useRestSsl,
      username: _user.text.trim(),
      password: _pass.text,
      transport: _transport,
      loginMethod: _loginMethod,
      hotspotName: _hotspot.text.trim().isEmpty ? 'hotspot1' : _hotspot.text.trim(),
      createdAt: base?.createdAt ?? DateTime.now(),
      enabled: _enabled,
    );
  }

  Future<void> _test(RouterServer server) async {
    setState(() => _busy = true);
    final res = await MikrotikService.testConnection(server);
    if (!mounted) return;
    setState(() => _busy = false);
    final ok = res['ok'] == 'true';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? Colors.green : Theme.of(ctx).colorScheme.error,
            size: 40),
        title: Text(ok ? 'Connexion réussie' : 'Échec de connexion'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: ok
                ? _resultTable([
                    ('Identité', res['identity'] ?? '—'),
                    ('Version', res['version'] ?? '—'),
                    ('Carte', res['board'] ?? '—'),
                    ('Uptime', res['uptime'] ?? '—'),
                    ('CPU', res['cpu'] ?? '—'),
                    ('Transport', res['transport'] ?? '—'),
                  ])
                : Text(res['error'] ?? 'Erreur inconnue'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _resultTable(List<(String, String)> rows) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(k,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(v, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final server = _buildServer();
    final app = context.read<AppState>();
    if (_isEdit) {
      await app.updateServer(server);
    } else {
      await app.addServer(server);
    }
    if (mounted) Navigator.of(context).pop(server);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le serveur' : 'Nouveau serveur'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nom du serveur',
                hintText: 'ex: Boutique Main, Rooftop, …',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nom obligatoire'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _host,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Adresse IP / hôte',
                hintText: 'ex: 192.168.88.1',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Adresse obligatoire'
                  : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _user,
                    decoration: const InputDecoration(
                      labelText: 'Utilisateur',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _hotspot,
              decoration: const InputDecoration(
                labelText: 'Nom du serveur hotspot',
                hintText: 'hotspot1',
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Transport & ports'),
            const SizedBox(height: 8),
            SegmentedButton<TransportChoice>(
              segments: const [
                ButtonSegment(
                  value: TransportChoice.auto,
                  label: Text('Auto'),
                  icon: Icon(Icons.auto_awesome, size: 18),
                ),
                ButtonSegment(
                  value: TransportChoice.api,
                  label: Text('API'),
                  icon: Icon(Icons.memory, size: 18),
                ),
                ButtonSegment(
                  value: TransportChoice.rest,
                  label: Text('REST'),
                  icon: Icon(Icons.cloud_outlined, size: 18),
                ),
              ],
              selected: {_transport},
              onSelectionChanged: (s) => setState(() => _transport = s.first),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final row1 = _portField(_apiPort, 'Port API', '8728', _useApiSsl,
                    (v) => setState(() => _useApiSsl = v));
                final row2 = _portField(_restPort, 'Port REST', '80', _useRestSsl,
                    (v) => setState(() => _useRestSsl = v));
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: row1),
                      const SizedBox(width: 12),
                      Expanded(child: row2),
                    ],
                  );
                }
                return Column(children: [
                  row1,
                  const SizedBox(height: 12),
                  row2,
                ]);
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<ApiLoginMethod>(
              segments: const [
                ButtonSegment(value: ApiLoginMethod.auto, label: Text('Auto'), icon: Icon(Icons.auto_awesome, size: 18)),
                ButtonSegment(value: ApiLoginMethod.v6, label: Text('v6')),
                ButtonSegment(value: ApiLoginMethod.v7, label: Text('v7')),
              ],
              selected: {_loginMethod},
              onSelectionChanged: (s) => setState(() => _loginMethod = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              'Auto détecte et peut retenter v7 puis v6 — fonctionne sur '
              'RouterOS 6.x, 7.11.2, 7.13.5 et plus récents.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Serveur activé'),
              subtitle: const Text('Visible et sélectionnable'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _test(_buildServer()),
                    icon: _busy
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Tester la connexion'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _portField(
    TextEditingController c,
    String label,
    String hint,
    bool useSsl,
    ValueChanged<bool> onSsl,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('TLS',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
            value: useSsl,
            onChanged: onSsl,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      );
}