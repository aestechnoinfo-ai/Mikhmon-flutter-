# Audit d'expiration des tickets Hotspot — conformité RouterOS v7

> Résultat de la recherche croisée (doc MikroTik *User Profiles* / *Hotspot*,
> forum MikroTik, Mikhmon v3 changelog 3.20, article Mahavikri, projet
> RootMikroManager) et de la revue du code de cette application.
>
> **Statut : la parade recommandée est déjà en place dans le code.**

## 1. Le problème rencontré « le ticket ne s'expire pas »

Cause racine classique de l'écosystème Mikhmon :

- Mikhmon ≤ v3.2x (et les scripts/schedulers maison qui en dérivent) calcule
  l'expiration **côté routeur** dans un script/scheduler qui **parse le texte
  de `/system clock get date`** sous la forme `jan/15/2019 16:05:11`.
- Depuis **RouterOS 7.10**, le format de `/system clock get date` change
  (ex. `2026-jan-15...`). Le parse par positions (`:pick $date 8 10`, etc.)
  casse **silencieusement** → la date d'échéance n'est plus jamais extraite →
  le scheduler ne désactive/supprime plus l'user → **le voucher ne s'expire plus**.
- Symptômes vus en production : users qui restent indéfiniment `disabled` ou
  qui conservent une session, tickets réutilisables après échéance, « expired »
  jamais déclenché.

## 2. Parade recommandée (validée par les sources)

1. **Ne pas se fier à un scheduler texte** qui dérive l'échéance d'un champ
   date formaté pour l'affichage.
2. S'appuyer sur l'**enforcement natif RouterOS** : poser, directement sur
   `/ip hotspot user`, les limites `limit-uptime` et `limit-bytes-total`.
   Le routeur déconnecte et refuse la reconnexion **tout seul**, v6 comme v7,
   sans étape calendaire côté app. C'est le comportement minimal et fiable.
3. Pour une **échéance calendaire** (`validityType = expires`, ex. « expire le
   dé 2026 ») : il faut explicitement **ne pas** traduire ça en un simple
   `limit-uptime` relancé à chaque reconnexion ; soit on gère la purge côté
   app (comparaison à une échéance fixe stockée localement), soit on conserve
   un piège si et seulement si le réseau reste en RouterOS < 7.10.
4. **Anti-partage / réutilisation abusive** (cause annexe fréquente de tickets
   qui « tournent en boucle ») :
   - `shared-users` sur le profil (déjà géré par `createHotspotProfile`), et
   - verrou MAC natif côté user (`mac-address` fixe) ou `add-mac-cookie`
     si l'on veut restreindre un ticket à un seul client.

## 3. État du code de cette application

| Mécanisme | Présent ? | Fichier |
| --- | --- | --- |
| `limit-uptime` natif envoyé à `/ip/hotspot/user` | ✅ | `mikrotik_service.dart` → `createHotspotUser` (`limitUptime`) |
| `limit-bytes-total` natif (quota volumétrique) | ✅ | `mikrotik_service.dart` → `createHotspotUser` (`limitBytesTotal`) |
| Format d'uptime RouterOS `D/HH:MM:SS` sans suffixe fragile | ✅ | `Formatters.toRouterosUptime` (`formatters.dart`) |
| Parse tolérant (prise en charge `Dd/HH:MM:SS` + format court) | ✅ | `Formatters.parseRouterosUptime` |
| `shared-users` sur les profils | ✅ | `createHotspotProfile` + `sharedUsers` du modèle |
| **Pas** de scheduler texte calculant l'expiration | ✅ (volontaire) | aucune création de scheduler de dates |
| Anti-usage multi-appareils (`mac-address` / cookie MAC par ticket) | ⚠️ partiel | manque un réglage par profil |

Le pont critique (le point 2) est donc **satisfait** : il n'y a pas de
dépendance à un scheduler cassable. Les échéances reposent sur l'enforcement
natif, qui est précisément ce que la documentation MikroTik recommande.

## 4. Améliorations possibles (à faire si besoin)

1. **Verrou MAC + anti-partage par profil** (intervalle le plus cité comme
   source de « tickets qui ne s'expirent pas correctement / se partagent ») :
   ajouter les options `mac-address` (user figé sur MAC) et `shared-users`,
   et – si l'admin le souhaite – `add-mac-cookie` sur le profil. Toujours
   déclinable par profil.
2. **Échéance calendaire réelle** : stocker une date d'échéance fixe
   (locale) et déclencher la suppression côté app, plutôt que de relancer
   `limit-uptime` à chaque login. Vérifier case par case que le profile
   concerné est en RouterOS < 7.10 si l'on veut l'ancien scheduler.
3. **Vérification end-to-end** : ajouter un test d'intégration qui lit
   `limit-uptime`/`limit-bytes-total` tels que renvoyés par un vrai routeur
   v7 et confirme `Formatters.parseRouterosUptime` (test actuellement
   impossible localement faute d'outillage Dart).
