# Tests de la base

Tout se teste sur un Postgres 16 **local et jetable**, jamais sur le projet Supabase.

```
bash docs/tests/lancer.sh
```

Le script (`docs/tests/lancer.sh`) crée un serveur temporaire (`initdb` dans `$TMPDIR`,
port 55433, socket Unix désactivée), le teste, puis l'arrête et l'efface. `GARDER=1` le
laisse tourner pour fouiller ; `PGBIN` et `PORT` se changent si besoin.

| Fichier | Rôle |
|---|---|
| `docs/tests/stubs-supabase.sql` | bouchons Supabase minimaux : rôles anon / authenticated / service_role, schémas `auth` (users, `uid()`, `role()`, `jwt()`) et `storage` (buckets, objects, `foldername()`), `pgcrypto` dans `extensions`, publication `supabase_realtime`, droits par défaut du schéma public comme Supabase |
| `docs/tests/scenario.sql` | le parcours complet, chaque vérification est un `assert` |
| `docs/tests/verif-donnees.sql` | ce qu'un nouveau passage d'INSTALLATION.sql ne doit pas changer |

## Ce qui est vérifié

1. `INSTALLATION.sql` passe deux fois de suite sur une base vierge, requête par requête.
2. Pareil en **une seule transaction** (`--single-transaction`), comme le SQL Editor de
   Supabase : la valeur d'enum `yearly_builder`, créée dans le même passage, n'est jamais
   comparée autrement qu'en texte.
3. Le scénario (`scenario.sql`) :
   - un admin et deux setters ; une introduction et 20 modules de démonstration, rangés
     tout seuls : Mensuel Builder 8, Annuel Starter 14, Annuel Builder 20 ;
   - la clé anon dépose un lead (`source = 'ace-club'`, `situation = 'Étudiant'`, UTM dans
     `page_url`) et compte deux visites ; elle ne peut ni lire les leads, ni déposer un lead
     attribué ou déjà vendu ;
   - le setter voit le lead libre (origine `tiktok`), le prend (premier appel compté) ; le
     second setter arrive trop tard ;
   - vente `yearly_builder` : la base impose 450 $ et **67,50 $** de commission, quoi que le
     navigateur envoie ; `crm_stats` et `classement_setters` le reflètent ;
   - `creer_acces_espace` : invitation `annuel_builder` (Annuel Builder), même lien si on
     rappelle ; refusée à l'autre setter ;
   - acceptation comme `api/invite-accept` (compte Auth, `members` avec la formule de
     l'invitation, `used_at` / `used_by`) : la fiche élève pointe vers son lead ;
   - l'élève au jour 1 : jour 1 « Ton offre et ta cible » ouvert, jour 2 avec compte à
     rebours ; programme fermé tant que le guide n'est pas fini, puis module 1 seul ; une
     leçon fermée n'est pas renvoyée ;
   - deux minuits plus tard (jour 3) : les modules 1 à 20 ouverts ; plafond au jour 10 ;
   - l'offre passe en `yearly` après l'inscription : la formule de l'élève suit (14
     modules) ; un lien pas encore utilisé est remplacé quand l'offre change (`monthly` →
     `mensuel`, 25 $) ;
   - `stats_sources` (1 visiteur, 2 vues, 2 formulaires, 2 ventes) et `rapport_pages` avec
     une clé de test (mauvaise clé refusée) ; `formules_recalculer()`.
4. Troisième passage d'INSTALLATION.sql sur la base remplie, après avoir changé un réglage et
   un titre : formules, élèves, ventes, réglages et titres restent identiques.
5. `remise-a-zero.sql` vide les leads.

## Dernière exécution (22/11/2026)

```
1. Base vierge, INSTALLATION.sql deux fois de suite (requête par requête)
  ✓ passage-1
  ✓ passage-2
2. Base vierge, deux fois en une seule transaction (comme le SQL Editor de Supabase)
  ✓ transaction-1
  ✓ transaction-2
3. Scénario : lead → setter → vente → commission → invitation → élève
  … (14 étapes)
  ✓ SCÉNARIO OK
4. Troisième passage sur la base remplie : rien ne doit bouger
  ✓ passage-3-avec-donnees
  avant : annuel=14 annuel_builder=20 mensuel=8|0|1|camille@test.local:yearly:250.00:31.25 lou@test.local:monthly:250.00:25.00|2|Le premier oui|1/3
  après : annuel=14 annuel_builder=20 mensuel=8|0|1|camille@test.local:yearly:250.00:31.25 lou@test.local:monthly:250.00:25.00|2|Le premier oui|1/3
  ✓ données intactes
5. Remise à zéro
  ✓ plus aucun lead
Tout est passé.
```

## Limites

- Les bouchons ne reproduisent ni PostgREST, ni GoTrue, ni le stockage : les appels HTTP du
  CRM, de la page et de l'espace membre ne sont pas testés ici. Les rôles et la RLS, si :
  le scénario se met dans la peau de chacun (`set role` + `request.jwt.claims`).
- Les fonctions `security definer` appartiennent ici à un superutilisateur ; sur Supabase,
  à `postgres`, qui passe lui aussi outre la RLS.
- À refaire sur le vrai projet une fois créé : un lead envoyé par la page, sa prise dans le
  CRM, une vente, le lien d'accès ouvert dans l'espace membre.
