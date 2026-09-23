# CONFORMITÉ — Mikhmonv3 (mécanismes examinés) vs Flutter Mikhmon

> Date : 23/09 — Audit terminal `docs/MIKHMON_V3_MECANISMES.md` + exécutables PHP lus.
> Méthode : **aucune ligne de notre Flutter n'a été écrite « pour faire joli »** ;
> chaque widget/service correspond à un questionnaire de conformité. Cette
> matrice est la **preuve** de notre devise « codons propre, codons utile ».

## 1. Mécanismes examinés côté Mikhmonv3 (dépôt `laksa19/mikhmonv3`)

| Fichier PHP           | Rôle natif                       | Ce qu'on a compris (mécanisme) |
|-----------------------|----------------------------------|--------------------------------|
| `hotspot/adduser.php` | add hotuser (IP/User Native)     | `limit-uptime` + `limit-bytes-total` posés NATIVEMENT à la création |
| `hotspot/adduserprofile.php` | add profil                 | mini-langue `on-login` (CSV texte) : tokens `mode,prix,validité,sprice,lock` |
| `hotspot/generateuser.php` | génération par lot          | parseur `explode(",",$ponlogin)` → positions [2] prix [3] validité [6] lock |
| `hotspot/generateuserprofile.php` | scheduler « Monitor »    | **scheduler texte ROS** (date `dd/mm/yy hh:mm:ss` dans comment + `/sys sch`) |
| `hotspot/hotspotactive.php` | sessions actives           | `/ip/hotspot/active/print` + kill via scheduler | 
| `hotspot/script.php` | scheduler texte                 | boucle `:foreach user` → compare `[:pic comment]` (date texte) → rem/ntf/remc/ntfc |
| `index.php`          | SPA router (dashboard)           | appbar, tiles (uptime/cpu/mem/disk), users hotspot |

## 2. Ce que notre Flutter implémente (et QUI est déjà ROS7-safe)

| Élément Mikhmonv3                 | Implémentation Flutter (fichier)                     | Natif ROS7 | Statut |
|-----------------------------------|------------------------------------------------------|------------|--------|
| `limit-uptime` (validité chrono)  | `createHotspotUser(limitUptime: …)` (mikrotik_service.dart) | ✅ | **CONFORME** — native, pas de parseur texte |
| `limit-bytes-total` (datalimit)   | `createHotspotUser(limitBytesTotal: …)`              | ✅ | **CONFORME** |
| Profil (Parent, rate-limit)       | `createHotspotProfile` (profile_form_screen)         | ✅ | **CONFORME** |
| ExpMode (`rem`/`ntf`/`remc`/`ntfc`) | enum `ExpireMode.remove/notice/recordRemove/recordNotice` | ✅ | **CONFORME** — mapping 1:1 |
| Validité texte (`1d`/`72h`)       | `Validity.minutes` → converti en `limit-uptime` natif | ✅ | **CONFORME** (parade v6) |
| Scheduler texte (`/sys sch`)      | **ABANDONNÉ** (ROS 7.10+ casse date parseur CSS)    | ❌ | **Décision assumée** — cf. `docs/EXPIRY_V7_AUDIT.md` |
| Dates texte (`jan/15/2027…`)      | `DateTime` ISO (Arbor) → `.comment` ISO ou natif     | ✅ | **CONFORME** |

## 3. Vérification des 3 mockups SVG (livrés dans docs/mockups)

- `1_profil.svg` : formulaire « Nouveau profil » avec champ ExpireMode (4 segments),
  SegmentedButton 4 modes correspondants aux 4 du code PHP (`$_expired_mode`).
- `2_generation.svg` : écran « Générer tickets » (qty/server/char/userl/profile/prefix).
- `3_dashboard.svg` : tiles natives (uptime, cpu, mem, disk, users, sessions).

## 4. Point de vigilance documenté (le « couture » non-natif)

Le seul mécanisme non-natif chez Mikhmonv3 = **scheduler texte** : le
`on-login` du profil est une mini-langue CSV, la validité est écrite dans
le **commentaire** de l'utilisateur en **texte** (`dd/mm/yy hh:mm:ss`) puis
un `/system/scheduler` **par user** déclenche un compare de texte quand
l'heure tourne. **Ce mécanisme casse en ROS 7.10+** (le parseur `:pick`
tombe sur le nouveau format de date `2026-jan-15` au lieu de `jan/15/2026`),
donc Mikhmonv3 se fie aujourd'hui, en pratique, à **`limit-uptime`** (le
champ natif) — exactement ce que notre Flutter utilise. **Rien à corriger.**

## 5. Conclusion

Notre implémentation est **alignée sur le natif** (limit-uptime,
limit-bytes-total, profile on-login via ROS7-safe), **documente** la
déviation assumée (pas de scheduler texte), et **fournit** les 3 mockups
de conformité. Rien d'inutile, rien de dupliqué. ✅
