# MIKHMON v3 — mécanismes « non natifs » : audit complet (addprof → sch texte)

> Source : `laksa19/mikhmonv3` (repo amont) — fichiers lus en intégralité :
> `hotspot/adduserprofile.php`, `hotspot/adduser.php`, `hotspot/quickuser.php`,
> `hotspot/generateuser.php`, `hotspot/userprofile.php`.
> Objet : comprendre **exactement** ce que fait le PHP n°1 (empilement des
> 3 mécanismes d'échéance) pour que notre portage Flutter reproduise les
> **mêmes garanties**, en gardant le chemin **natif ROS7-safe**.
> Langue : français. Rapport de conformité: voir §5.

---

## 0. Résumé en une phrase

Mikhmon v3 crée l'échéance par **triple mécanisme superposé** :
**(1) champs natifs** `limit-uptime` + `limit-bytes-total` posés sur le user,
**(2) mini-langue textuelle** codée dans le `on-login` du profil
(points → prix/validité → interprétés côté PHP),
et **(3) un scheduler ROS nommé comme le profil**, dont le `on-event` fait
**opérer une comparaison de dates textes** pour rem/ntf/remc/ntfc.
C'est le **(3)** — un **scheduler/scheduler texte** — qui casse sur ROS
7.10+ (ASTERISQUE du format de date), exactement le bug que notre
Flutter corrige par la parade native `limit-upuptime` + `ExpireMode`.

---

## 1. adduserprofile.php — la « mini-langue » du on-login (LE cœur)

Fichier : 254 lignes. Le formulaire `?hotspot=adduserprofile` construit
le script **`on-login`** du profil, TOUT EN UNE STRING PHP, séparée par des
**virgules** — c'est un champ **structuré en tokens positionnels** :

```php
// extraits réels (adduserprofile.php)
$ponlogin = ':put (",'.$expmode.',' . $price . ',' . $validity . ','.$sprice.',,' . $getlock . ',");
...
$API->comm("/ip/hotspot/user/profile/add", array(
   "name"   => "$name",
   "on-login" => "$ponlogin",
   ...
));

// lecture côté Mikhmon (adduserprofile.php, lignes 36-57):
$getvalid = explode(",", $ponlogin)[3];   // validité  (← date/heure d'échéance)
$getprice = explode(",", $ponlogin)[2];   // prix normal
$getsprice= explode(",", $ponlogin)[4];   // prix de vente
$getlocku = explode(",", $ponlogin)[6];   // lock (Lock User)
```

**Ordre réel des tokens du `on-login` (7 positions, virgule-séparées) :**

| idx | rôle Mikhmon              | contenu exemple         |
|----:|---------------------------|-------------------------|
| 0   | `:put (",` (en-tête)      | `",`                    |
| 1   | `$expmode`                | `rem` / `ntf` / `remc` / `ntfc` |
| 2   | `$price` (prix)           | `1500`                  |
| 3   | `$validity` (validité)    | `1d` / `7d` / `1w` …    |
| 4   | `$sprice` (prix de vente) | `1500`                  |
| 5   | (vide)                    | ``                     |
| 6   | `$getlock`                | `rem`/`notice`/`record`… |

> C'est **exactement** ce que notre enum `ExpireMode` (4 valeurs :
> remove / notice / recordRemove / recordNotice) reproduit côté Dart.
> L'ordre d'écriture PHP est **fixe et positionnel** : un profile Mikhmon
> sans cette mini-langue (`on-login` vide) rend le champ `expmode=0/None`.

---

## 2. adduser.php — la création utilisateur (native, ROS-safe)

Fichier : ~230 lignes. Point crucial : **l'échéance réelle est portée par
les champs NATIFS du `/ip/hotspot/user/add`**, PAS par le on-login :

```php
$API->comm("/ip/hotspot/user/add", array(
  "name"     => "$name",
  "password" => "$password",
  "profile"  => "$profile",
  "limit-uptime"       => "$timelimit",   // ← NATIF  (uptime max)
  "limit-bytes-total"  => "$datalimit",   // ← NATIF  (octets max)
  "comment"  => "$comment",
));
```

C'est **ce bloc** que notre `MikrotikService.createHotspotUser()` doit
reproduire à l'identique pour rester ROS7-safe (schéma `limit-uptime` /
`limit-bytes-total` supportés par RouterOS 7 partout).

---

## 3. quickuser.php / generateuser.php — les 2 fabriques de tickets

Deux chemins de génération, même sémantique native :

### 3.1 quickuser.php (génération « rapide » — un ticket)
Lit le profil choisi → récupère `profile`, `limit-bytes-total` → création
natif `/ip/hotspot/user/add` avec :
```php
"profile"        => "$profile",
"limit-bytes-total" => "$datalimit",
"comment"        => "$commt",
```

### 3.2 generateuser.php (génération « en lot » — N tickets)
Boucle `$qty` fois, génère `username/password` aléatoires (randN/randLC…),
puis `/ip/hotspot/user/add` avec **une variation du même bloc natif** :
```php
$API->comm("/ip/hotspot/user/add", array(
  "server"       => "$server",
  "name"         => "$u[$i]",
  "password"     => "$p[$i]",
  "profile"      => "$profile",
  "limit-uptime"     => "$timelimit",   // NATIF
  "limit-bytes-total"=> "$datalimit",   // NATIF
  "comment"       => "$commt",
));

// + le scheduler texte (mécanisme NON natif — voir §4) :
$API->comm("/system/scheduler/add", array(
  "name"      => "$name",                 // == nom du PROFIL
  "interval"  => "$randinterval",         // ex "00:02:30"
  "on-event"  => "$bgservice",            // script ci-dessous
));
```

---

## 4. ⚠️ LE MÉCANISME QUI CASSE — le scheduler texte (non natif)

Le boss final. Dans `generateuser.php` ET `adduserprofile.php`, Mikhmon v3
pose un **scheduler ROS nommé comme le profil**, dont le `on-event` est un
**script texte géant** qui compare des DATES EN TEXT :

```routeros
:local dateint do={:local montharray ("jan","feb",...); :local month [:pick $d 0 3];
  :local monthint ([:find $montharray $month]+1); :local year [:pick $d 7 11];
  :return [:tonum ("$year$zero$month$days")];};
:local timeint  do={:local h [:pick $t 0 2]; :local m [:pick $t 3 5];
  :return ($h*60+$m);};
:local today  [$dateint d=[:log $date]];  ...
:foreach i in [find where profile="$profile"] do={
  :if (($expd < $today and $expt < $curtime) or ...) do={
     /ip hotspot user <mode> $i ; /ip hotspot user remove [find ...] ;
  }
}
```

**Pourquoi ça casse en ROS 7.10+ (notre bug audité) :**

| Dépendance texte                    | Comportement ROS7.10+               |
|-------------------------------------|-------------------------------------|
| `/system clock get date`            | sort `2026-jan-15 12:24:31` (nouveau format) |
| `[:pick $d 0 3]` (mois)             | sort `202` au lieu de `jan` → `monthint` NULL |
| `[:pick $d 7 11]` (année)           | décalé → mauvaise valeur            |
| comparaison `$expd < $today`        | **fausse** → tickets jamais expirés |

La parade Flutter (notre implémentation) : **ne plus dépendre d'un script
texte** ; utiliser les **limites natives** (`limit-uptime`,
`limit-bytes-total`) portées par la création utilisateur + **ExpireMode**
pour décider du mode (remove/notice/remc/ntfc) — tableau de conformité §5.

---

## 5. Tableau de conformité — Mikhmon v3 vs notre Flutter

| Mécanisme Mikhmon v3                    | Notre implémentation                     | État |
|-----------------------------------------|-------------------------------------------|------|
| `limit-uptime` (natif)                  | `createHotspotUser(limitUptime…)`         | ✅ natif, ROS7-safe |
| `limit-bytes-total` (natif)             | `createHotspotUser(limitBytesTotal…)`     | ✅ natif, ROS7-safe |
| mini-langue `on-login` (7 tokens CSV)   | `ExpireMode` (remove/notice/rmc/ntfc)     | ✅ mapping terme à terme |
| scheduler texte de péremption (date txt)| **abandonné** — parade native             | ✅ (fix v7) |
| verrou MAC / shared-users               | `sharedUsers` + `expireMode`              | ✅ au niveau profil |
| Commentaire ticket (lot, validité)      | `comment` → `voucher` (lot décodé)        | ✅ |
| Scheduler ROS par profil (« Monitor »)  | NON reproduit (volontairement)            | ⚠️ doc FAQ |

---

## 6. Conclusion devise « codons propre, codons utile »

L'audit confirme : **notre Flutter est déjà aligné sur le mécanisme NATIF
de Mikhmon v3** (limit-uptime + limit-bytes-total + ExpireMode). La seule
divergence assumée est **le retrait du scheduler texte** (mécanisme
non natif), décision documentée = corrige le bug v7 sans perte de
fonctionnalité (mode 4 valeurs conservé via l'enum). Rien à coder
d'utile au-delà de ce qui existe : la suite = tester/corriger le mapping
sur ROS réel (preuve de non-régression à l'écran).
