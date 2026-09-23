# -*- coding: utf-8 -*-
"""Génère 3 mockups SVG de conformité (mockups/*.svg) fidèles aux labels
réels du code Flutter (/root/mikhmon). Valide XML + équilibre avant écriture.

Uniquement du SVG pur (pas de PNG — pas d'outil raster sur cet hôte).
"""
import os, html as H
import xml.etree.ElementTree as ET

W, Hh = 400, 860
INK = '#1f2437'; MUT = '#8b92a6'; MUT2 = '#aab0c2'
ACC = '#7c4dff'; ACC_SOFT = '#ece8ff'; BORD = '#e2e5ee'; CARD = '#ffffff'
SECT = '#e9e6f7'

def _esc(t): return H.escape(str(t), quote=True)

def node(tag, x=None, y=None, **kw):
    a = ''
    if x is not None: a += f' x="{x}"'
    if y is not None: a += f' y="{y}"'
    for k, v in kw.items():
        if v is None: continue
        a += f' {k.replace("_", "-")}="{_esc(v)}"'
    return f'<{tag}{a}/>'

def T(t, x, y, size=13, fill=INK, weight='400', anchor=None):
    a = f' x="{x}" y="{y}" font-size="{size}" fill="{fill}" font-weight="{weight}"'
    if anchor: a += f' text-anchor="{anchor}"'
    return f'<text{a}>{_esc(t)}</text>'

def rect(x, y, w, h, rx=12, fill=CARD, stroke=BORD, sw=1.2, **kw):
    return node('rect', x=x, y=y, width=w, height=h, rx=rx, fill=fill,
                stroke=stroke, stroke_width=sw, **kw)

def field(x, y, label, value, w=364, h=64, hint=None, hint_style=None):
    out = [rect(x, y, w, h)]
    out.append(T(label, x + 16, y + 24, 11.5, MUT))
    out.append(T(value, x + 16, y + 46, 14, INK, '600'))
    if hint:
        out.append(T(hint, x + 16, y + h - 8, 9.5, MUT2))
    return out

def section(x, y, s, w=364):
    return [rect(x, y, w, 40, 8, fill=SECT, stroke='none'),
            T(s, x + 16, y + 25, 12.5, ACC, '700')]

def chip(x, y, label, active=False, w=178, h=44, rx=22):
    if active:
        return [rect(x, y, w, h, rx, fill=ACC, stroke='none'),
                T(label, x + w / 2, y + h / 2 + 5, 12.5, '#fff', '700', 'middle')]
    return [rect(x, y, w, h, rx, fill='#f3f1fb', stroke=BORD),
            T(label, x + w / 2, y + h / 2 + 5, 12.5, INK, '600', 'middle')]

def header(title, action):
    return [rect(0, 0, W, 62, 0, fill=INK, stroke='none'),
            T(title, 8, 42, 26, ACC, '400')] if False else [
        rect(0, 0, W, 62, 0, fill=INK, stroke='none'),
        T(title, 16, 39, 18, '#fff', '700'),
        T(action, 354, 39, 13, ACC_SOFT, '700', 'end')]

def fieldrow(x, y, l1, v1, l2, v2):
    return (field(x, y, l1, v1, 176) +
            field(x + 190, y, l2, v2, 176))

def appbar(title, action, subtitle=None):
    out = [rect(0, 0, W, 64, 0, fill=INK, stroke='none')]
    if subtitle:
        out.append(T(subtitle, 16, 26, 10.5, MUT2))
        out.append(T(title, 16, 45, 18, '#fff', '700'))
    else:
        out.append(T(title, 16, 40, 17, '#fff', '700'))
    if action:
        out.append(T(action, 356, 40, 13.5, '#b9a6ff', '700', 'end'))
    return out

def btn(x, y, label, w=364, h=50, enabled=True):
    bg = ACC if enabled else '#c9c6dd'
    return [rect(x, y, w, h, h / 2, fill=bg, stroke='none'),
            T(label, x + w / 2, y + h / 2 + 5, 14, '#fff', '700', 'middle')]

def go(name, els):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{Hh}" '
           f'viewBox="0 0 {W} {Hh}" font-family="\'Segoe UI\', system-ui, sans-serif">'
           + ''.join(els) + '</svg>')
    try:
        ET.fromstring(svg)
    except ET.ParseError as e:
        print(f'XML INVALID {name}: {e}')
        return False
    p = os.path.join('docs/mockups', name)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(svg)
    print(f'OK  {p}  ({len(svg)} o)')
    return True

# ============ 1 — CRÉATION PROFIL ============
e1 = appbar('Nouveau profil', 'Enregistrer')
e1 += field(18, 92, 'Nom du profil', 'Voucher-48h')
e1 += field(18, 168, 'Prix (€)', '1,50')
e1 += section(20, 262, 'Validité')
e1 += chip(18, 314, 'Durée (uptime)', True, 178)
e1 += chip(206, 314, 'Date d'expiration', False, 178)
e1 += field(18, 372, 'Durée (heures)', '48',
            hint='ex : 1 = 1 h, 24 = 1 j, 168 = 1 semaine')
e1 += section(20, 470, 'Action à l'échéance')
e1 += chip(18, 522, 'Remove (suppr.)', True, 106)
e1 += chip(132, 522, 'Notice', False, 118)
e1 += chip(258, 522, 'Record + suppr.', False, 126)
e1 += chip(18, 578, 'Record + prév.', False, 170)
e1 += fieldrow(18, 666, 'Débit (kbps)', '0 (illimité)', '', '')
e1 += btn(18, 780, 'Enregistrer le profil')

# ============ 2 — GÉNÉRATION TICKETS ============
e2 = appbar('Génération', '')
e2 += field(18, 92, 'Serveur / Routeur', 'router-01 (10.0.0.1 · ROS 7.16)')
e2 += field(18, 176, 'Profil', 'Voucher-48h — expire 48 h calendaire depuis 1er login')
e2 += field(18, 260, 'Quantité', '10')
e2 += section(20, 360, 'Résumé du lot')
e2 += field(18, 412, 'Échéance', '1er login + 48 h (calendaire)')
e2 += field(18, 496, 'Action à l'échéance', 'Remove — purge native (ROS 7-safe)')
e2 += section(20, 596, 'Aperçu')
e2 += field(18, 648, 'Ticket 1', 'user:V48-8F2K · mdps:x9P4q7 · 48 h')
e2 += btn(18, 780, 'Générer le lot de 10')

# ============ 3 — DASHBOARD ============
e3 = appbar('Tableau de bord', 'Actualiser', 'router-01')
tiles = [('Uptime', '2 j 04 h'), ('Charge CPU', '12 %'),
         ('Mémoire', '38 %'), ('Disque', '21 %'),
         ('Users hotspot', '42'), ('Sessions actives', '4')]
x, y = 18, 92
for i, (lab, val) in enumerate(tiles):
    if i == 4:
        x, y = 18, 330
    if i == 6:
        x, y = 18, 330
    e3 += field(x, y, lab, val, 176, 84)
    x += 190
    if i == 1 or i == 3:
        x, y = 18, y + 82
e3 += section(20, 400, 'Informations')
info = [('Version RouterOS', '7.16 — v7-safe, scheduler texte désactivé'),
        ('Identité', 'Hotspot Central'),
        ('Date de build', '23 sept. 2026'),
        ('Transport', 'API binaire RouterOS (8728 — TLS 8729)')]
yy = 452
for lab, val in info:
    e3 += field(18, yy, lab, val)
    yy += 72
e3 += btn(18, 780, 'Ouvrir la génération de tickets')

ok = True
os.makedirs('docs/mockups', exist_ok=True)
ok &= go('01_creation_profil.svg', e1)
ok &= go('02_generation_tickets.svg', e2)
ok &= go('03_dashboard.svg', e3)
print('TOUS VALIDES' if ok else 'ERREURS')
