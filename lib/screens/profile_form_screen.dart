import 'package:flutter/material.dart';
import '../models/hotspot_profile.dart';
import '../core/utils/uid.dart';

/// Formulaire d'édition d'un profil hotspot.
class ProfileFormScreen extends StatefulWidget {
  final HotspotProfile? profile;
  const ProfileFormScreen({super.key, this.profile});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _hours;
  late final TextEditingController _days;
  late final TextEditingController _up;
  late final TextEditingController _down;
  late final TextEditingController _shared;
  late final TextEditingController _comment;

  late ValidityType _validity;
  late ExpireMode _expireMode;
  late final _ExpireMenuKey = GlobalKey<FormFieldState<ExpireMode>>();

  bool get _isEdit => widget.profile != null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(
        text: p == null ? '' : (p.price == p.price.roundToDouble()
            ? p.price.toStringAsFixed(0)
            : p.price.toStringAsFixed(2)));
    final h = (p?.uptimeSeconds ?? 3600) / 3600;
    _hours = TextEditingController(
        text: p == null || p.validityType == ValidityType.expires
            ? ''
            : h.toStringAsFixed(h == h.roundToDouble() ? 0 : 1));
    _days = TextEditingController(text: '${p?.expiresDays ?? 0}');
    _up = TextEditingController(text: '${p?.uploadKbps ?? 0}');
    _down = TextEditingController(text: '${p?.downloadKbps ?? 0}');
    _shared = TextEditingController(text: '${p?.sharedUsers ?? 0}');
    _comment = TextEditingController(text: p?.comment ?? '');
    _validity = p?.validityType ?? ValidityType.uptime;
    _expireMode = p?.expireMode ?? ExpireMode.remove;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _price, _hours, _days, _up, _down, _shared, _comment
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _parseKbps(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v < 0) return null;
    return v;
  }

  HotspotProfile _build() {
    final base = widget.profile;
    final uptimeSeconds = _validity == ValidityType.uptime
        ? (double.tryParse(_hours.text.trim().replaceAll(',', '.')) ?? 0)
            .round() * 3600
        : 0;
    final expiresDays = _validity == ValidityType.expires
        ? (int.tryParse(_days.text.trim()) ?? 0)
        : 0;
    return HotspotProfile(
      id: base?.id ?? generateUid(),
      serverId: base?.serverId,
      name: _name.text.trim(),
      price: double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0,
      uptimeSeconds: uptimeSeconds,
      expiresDays: expiresDays,
      validityType: _validity,
      expireMode: _expireMode,
      uploadKbps: _parseKbps(_up) ?? 0,
      downloadKbps: _parseKbps(_down) ?? 0,
      sharedUsers: int.tryParse(_shared.text.trim()) ?? 0,
      comment: _comment.text.trim(),
      synced: base?.synced ?? false,
      createdAt: base?.createdAt ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le profil' : 'Nouveau profil'),
        actions: [
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop(_build());
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nom du profil',
                hintText: 'ex: 1H-1Mbps',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nom obligatoire'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix',
                prefixIcon: Icon(Icons.euro),
              ),
              validator: (v) {
                final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (d == null || d < 0) return 'Prix invalide';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _sectionTitle('Validité'),
            const SizedBox(height: 8),
            SegmentedButton<ValidityType>(
              segments: const [
                ButtonSegment(
                  value: ValidityType.uptime,
                  label: Text('Durée (uptime)'),
                  icon: Icon(Icons.timer_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ValidityType.expires,
                  label: Text('Date d’expiration'),
                  icon: Icon(Icons.event_outlined, size: 18),
                ),
              ],
              selected: {_validity},
              onSelectionChanged: (s) => setState(() => _validity = s.first),
            ),
            const SizedBox(height: 14),
            if (_validity == ValidityType.uptime)
              TextFormField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Durée (heures)',
                  hintText: 'ex: 1 = 1 heure, 24 = 1 jour, 168 = 1 semaine',
                  prefixIcon: Icon(Icons.schedule),
                ),
                validator: (v) {
                  final d = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                  if (d == null || d <= 0) return 'Durée invalide';
                  return null;
                },
              )
            else
              TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jours avant expiration',
                  prefixIcon: Icon(Icons.event_available_outlined),
                ),
              ),
            const SizedBox(height: 18),
            _sectionTitle('Action à l\u2019expiration'),
            const SizedBox(height: 4),
            Text(
              'Comportement de RouterOS quand le ticket arrive \u00e0 \u00e9ch\u00e9ance. '
              'remove = suppression, notice = d\u00e9sactivation + pr\u00e9vention, '
              'record = tra\u00e7abilit\u00e9 de l\u2019\u00e9v\u00e9nement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ExpireMode>(
              segments: const [
                ButtonSegment(
                  value: ExpireMode.remove,
                  label: Text('Supprimer'),
                  icon: Icon(Icons.delete_outline, size: 18),
                ),
                ButtonSegment(
                  value: ExpireMode.notice,
                  label: Text('Pr\u00e9venir'),
                  icon: Icon(Icons.notifications_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ExpireMode.recordRemove,
                  label: Text('Consigner + suppr.'),
                  icon: Icon(Icons.fact_check_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ExpireMode.recordNotice,
                  label: Text('Consigner + pr\u00e9v.'),
                  icon: Icon(Icons.assignment_outlined, size: 18),
                ),
              ],
              selected: {_expireMode},
              onSelectionChanged: (s) =>
                  setState(() => _expireMode = s.first),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Débit (kbps)'),
            const SizedBox(height: 4),
            Text(
              '0 = illimité. Utilisé dans le profil RouterOS '
              '(rate-limit download/upload).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _down,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Téléchargement',
                      prefixIcon: Icon(Icons.arrow_downward),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _up,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Envoi',
                      prefixIcon: Icon(Icons.arrow_upward),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _shared,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Users partagés (0 = illimité)',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _comment,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context).pop(_build());
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer le profil'),
            ),
          ],
        ),
      ),
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