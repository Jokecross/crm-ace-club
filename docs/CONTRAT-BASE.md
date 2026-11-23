# Contrat de base — ACE Club

Une seule base Supabase pour la page de vente ACE Club, le CRM (ce dossier) et
l'espace membre (`~/Espace Membre ACE Club`). Elle s'installe avec un seul fichier :
`supabase/INSTALLATION.sql` (rejouable, testé : `docs/TESTS.md`).

Base de départ : la base du CRM Sirius au dernier commit, **moins** Skool (équipe,
réservations, dispos, formule Skool), Hermès, Whop / opt-in / paiement 9,99 €, l'offre
JVJ, la garantie et les contrats, Affiliate Consulting, les ventes envoyées à Meta et le
parcours automatique. Le workshop passe de 7 à 10 jours.

## Écarts par rapport au contrat annoncé

Aucun nom de table, de colonne ou de fonction n'a changé pour ce que l'espace membre
utilise. Les seules différences, toutes des ajouts ou des retraits annoncés :

| Point | Ce qu'il en est |
|---|---|
| `contrats`, `garanties`, `contrat_lire`, `contrat_signer`, `garantie_*`, `garanties_suivi`, `paiement_confirme` | **absents** (garantie retirée) |
| Formule `skool`, `skool_sans_module`, `skool_sans_contrat` | **absents** |
| `visionnages` + `visionnage_noter(p_lesson, p_duree, p_secondes)` | **gardés** : suivi Loom seconde par seconde, la vidéo se coche seule à 95 %. Ils venaient de la migration garantie mais ne dépendent de rien d'autre. Inutile de les appeler si l'espace n'en a pas besoin. |
| `workshop_reglages.prompt_secours` | colonne présente, **vide** (le texte de Sirius n'est pas repris) |
| `workshop_reglages.prompts_sos` | colonne présente, `{}` (aucun prompt Kairo) |
| `prochaines_etapes` | une ligne, `actif = false`, texte `[À COMPLÉTER …]` |
| Nouveau : `formules_recalculer()` | renumérote les trois formules d'après `modules.position` (voir plus bas) |
| Nouveau : `members.lead_id` rempli à l'acceptation | déclencheur `trg_invitation_acceptee` sur `invites` |
| Nouveau : `creer_acces_espace(p_lead)` | côté CRM (le setter crée l'invitation après la vente) |

## Tables utilisées par l'espace membre

| Table | Colonnes |
|---|---|
| `members` | id, lead_id, email, first_name, last_name, role (`member` \| `setter` \| `admin`), activated_at, plan_code, workshop_debut_at, workshop_dispense, fuseau, guide_etape, guide_fait_at, prompt_recu, tour_fait_at |
| `plans` | code, label, rank, dernier_module |
| `plan_modules` | plan_code, module_id |
| `invites` | token, plan_code, label, created_by, created_at, expires_at (+14 j), used_at, used_by |
| `modules` | id, position, title, description, is_intro, is_bonus |
| `lessons` | id, module_id, position, title, video_path, duration_seconds, vimeo_url, document_path, document_name, avertissement, sous_video (jsonb) |
| `lesson_progress` | member_id, lesson_id, completed_at |
| `workshop_jours` | jour (1..10), titre, resume, video_url, prompt, prompt_2, prompt_2_titre, consignes, etapes (jsonb), updated_at |
| `workshop_reglages` | id = 1, modules_avant_j3 (1), jour_deblocage (3), fuseau (Europe/Paris), bandeau_actif, bandeau_texte, bandeau_lien_texte, prompt_j0, video_systeme_url, prompt_secours, prompts_sos, updated_at |
| `workshop_captures` | member_id, jour (0..10), file_path, file_name, taille, created_at |
| `preuves` | member_id, file_path, file_name, taille, statut, motif, created_at, updated_at |
| `prochaines_etapes` | id = 1, actif, eyebrow, titre, texte, cta_libelle, cta_url, note, updated_at |
| `resources` | id, position, kind (`fichier` \| `prompt`), title, description, file_path, file_name, prompt_text, created_at |
| `tools` | id, position, name, description, promo_code, url, created_at |
| `visionnages` | member_id, lesson_id, duree, vues, pourcentage, maj |
| vue `suivi_workshop` | id, prenom, email, plan_code, activated_at, jour, captures, dernier_jour_depose, derniere_capture_at, jours_de_retard |

Seaux de stockage (privés) : `videos` (vidéos et PDF des leçons, ressources), `preuves`
(preuves et captures du workshop), plus `factures` et `appels` côté CRM.

## Fonctions (RPC) de l'espace membre

`my_modules()`, `is_module_unlocked(p_member, p_module)`, `has_module`, `module_completion`,
`plan_matrix()`, `etat_portes()`, `mon_guide()`, `guide_avancer(p_etape, p_prompt_recu)`,
`guide_termine()`, `tour_termine()`, `workshop_demarrer(p_fuseau)`, `workshop_jour(p_member)`,
`mon_workshop()`, `mon_etat_workshop()`, `visionnage_noter(p_lesson, p_duree, p_secondes)`,
`is_equipe(p_user)`, `is_admin(p_user)`. Mêmes signatures et mêmes colonnes de retour que la
base Sirius.

## Formules

| Code | Libellé | Modules | Offre vendue dans le CRM |
|---|---|---|---|
| `mensuel` | Mensuel Builder | 1 à 8 | `monthly` (200 $, 10 %) |
| `annuel` | Annuel Starter | 1 à 14 | `yearly` (250 $, 12,5 %) |
| `annuel_builder` | Annuel Builder | 1 à 20 | `yearly_builder` (475 $, 15 % = 71,25 $) |

Les numéros comptent les modules du programme dans l'ordre de `position`, sans les
introductions (`is_intro`) ni les bonus (`is_bonus`). Un module inséré est coché tout seul
dans les formules dont `dernier_module` ≥ son numéro (déclencheur
`trg_module_dans_les_formules`). **Pour le script de données des 20 modules** : insère-les
dans l'ordre des positions, ou termine par

```sql
select * from public.formules_recalculer();   -- SQL Editor (service_role) seulement
```

qui renumérote tout d'un coup (attendu : mensuel 8, annuel 14, annuel_builder 20). Les
introductions sont ouvertes à toutes les formules sans ligne dans `plan_modules` ; un bonus
doit être coché à la main dans les formules qui le contiennent.

## Règles d'ouverture (inchangées, sauf 7 → 10)

- Jour 1 du workshop ouvert dès l'inscription (`activated_at`, ou `workshop_debut_at` posé
  à la main), un jour de plus à chaque minuit dans le fuseau de l'élève, jusqu'au jour 10.
  L'équipe et les élèves `workshop_dispense` ont les 10 jours.
- Le programme : l'introduction d'abord (la fin du guide la coche), puis
  `modules_avant_j3` module(s) (1) avant le jour `jour_deblocage` (3), et tous les modules
  de la formule à partir du jour 3. Les bonus s'ouvrent dès l'arrivée.
- Les dix jours en base : 1 Ton offre et ta cible · 2 Ton premier site avec l'IA · 3 Le
  rendre pro · 4 Ton prix · 5 Trouver tes prospects · 6 La maquette qui vend · 7 Tes premiers
  messages · 8 Les relances · 9 Le rendez-vous · 10 Le premier oui. Prompts, vidéos et
  étapes vides.

## L'invitation, de la vente à l'inscription

1. Le sales passe le lead en `monthly`, `yearly` ou `yearly_builder` dans le CRM.
2. Le CRM appelle `rpc/creer_acces_espace { p_lead }` → `{ token, plan_code, plan_label,
   expires_at, deja_inscrit }`. La base choisit la formule d'après l'offre, crée l'invitation
   (14 jours, usage unique) et l'écrit dans `leads.invite_token`. Si l'offre change avant
   l'inscription, l'ancien lien est supprimé et un nouveau part ; après l'inscription, la
   formule de l'élève suit l'offre.
3. Le lien envoyé est `${ESPACE_URL}/bienvenue/<token>`.
4. `api/invite-accept` de l'espace membre (inchangé par rapport à Sirius, clé service_role) :
   lit `invites` (token, plan_code, used_at, expires_at), crée le compte Auth, `upsert`
   `members` { id, email, first_name, last_name, plan_code }, puis met `used_at` et `used_by`
   sur l'invitation. Le déclencheur `trg_invitation_acceptee` relie alors `members.lead_id`
   au lead.

## Ce que la page de vente utilise

- `insert` dans `leads` avec la clé anon : first_name, last_name, email, phone, page_url,
  source (`ace-club`), situation (≤ 40 caractères), et si `COLONNES_SUIVI = true` : ref,
  utm_source, utm_medium, utm_campaign, utm_content, utm_term (≤ 120 caractères chacun). Les
  colonnes existent : `COLONNES_SUIVI` peut passer à `true` dans `reglages.js`.
  La clé anon ne peut qu'insérer, dans `equipe = 'starter'` et `vivier = 'formulaire'`
  (valeurs par défaut), sans aucun champ de suivi.
- `rpc/visite_compter { p_visiteur uuid, p_origine text }` (anon), pour l'onglet Sources.
