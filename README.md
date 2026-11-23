# CRM des setters — ACE Club

Back-office des setters d'ACE Club (agence qui vend des sites web faits avec l'IA aux
commerces). Le parcours : page de vente → formulaire → un setter appelle dans les 10
minutes → vente d'un abonnement au logiciel IA partenaire (Base44, par le lien
d'affiliation d'ACE Club) → accès à l'espace membre.

Repris du CRM Sirius (même mécanique, équipe Base44 seulement), lui-même repris de
Marcuus et Mexed. Un seul fichier (`index.html`), sans build : Vercel le sert tel quel. Il
lit et écrit dans **la base Supabase d'ACE Club**, la même que la page de vente
ACE Club et l'espace membre (`~/Espace Membre ACE Club`).

**État : tout est en local.** Le projet Supabase n'existe pas encore ; rien n'est en ligne.
Ce qui reste à brancher : `A-COMPLETER.md`.

```
index.html                    le CRM (HTML, CSS, JS), charte ACE Club
rapport.html                  le rapport sans connexion (rapport.html#<clé>)
img/, fonts/                  logo, favicon, Archivo et Inter (servis avec le site)
supabase/INSTALLATION.sql     toute la base : leads, CRM, espace membre (unique, rejouable)
supabase/remise-a-zero.sql    vide les données de test
scripts/creer-comptes.mjs     crée le premier admin et les comptes de l'équipe
scripts/equipe.json           la liste de l'équipe
scripts/cle-rapport.mjs       tire la clé du rapport
docs/CONTRAT-BASE.md          ce que l'espace membre et la page attendent de la base
docs/TESTS.md, docs/tests/    les tests de la base sur un Postgres local
A-COMPLETER.md                ce qu'il reste à fournir ou à décider
```

## Le parcours d'un lead

1. Le formulaire de la page de vente insère une ligne dans `leads` (équipe `starter` =
   Base44, vivier `formulaire`, `source = 'ace-club'`, `situation`). Le formulaire est
   gratuit : pas d'opt-in, pas de paiement, le lead entre tout de suite dans les Leads du
   jour.
2. Il apparaît en temps réel dans **Leads du jour**, avec un compte à rebours de 10
   minutes. Le premier setter qui le prend l'a pour lui.
3. Le setter l'appelle, change le statut. C'est la base qui fixe le montant et la
   commission :

   | Statut | Offre | Cash | Commission du setter |
   |---|---|---|---|
   | `monthly` | Mensuel Builder | 250 $ | 10 % = 25,00 $ |
   | `yearly` | Annuel Starter | 250 $ | 12,5 % = 31,25 $ |
   | `yearly_builder` | Annuel Builder | 450 $ | 15 % = 67,50 $ |

4. Dans la fiche, **Créer l'accès** : la base crée une invitation à usage unique (14 jours)
   pour la formule de l'offre vendue (Mensuel Builder → modules 1 à 8, Annuel Starter → 1 à
   14, Annuel Builder → 1 à 20) et le CRM affiche le lien `ESPACE_URL/bienvenue/<jeton>` à
   copier ou à envoyer par WhatsApp ou e-mail. Si l'offre change ensuite, la formule suit.
5. L'élève ouvre le lien, crée son mot de passe, et arrive dans l'espace membre : jour 1 du
   workshop de 10 jours ouvert, un jour de plus chaque minuit.

Onglets : Leads du jour, Pipeline, Relances, Archive, Dashboard (cartes de taux),
Classement, Factures, Rapport, Sources (visites → formulaires → ventes, par lien), Présence.
Les comptes avec `staff.vues` n'ont que les onglets listés.

## Installer (quand le projet Supabase existera)

1. Projet Supabase d'ACE Club → **SQL Editor** → coller `supabase/INSTALLATION.sql` →
   **Run**. Rejouable : testé deux fois de suite, et en une seule transaction
   (`docs/TESTS.md`).
2. Authentication → Sign In / Providers → désactiver **Allow new users to sign up**.
3. Renseigner `SUPABASE_URL` et `SUPABASE_ANON` en haut du script d'`index.html` (tant
   qu'ils sont vides, la connexion affiche « Configuration Supabase manquante »), les mêmes
   dans `rapport.html`, dans `reglages.js` de la page de vente et dans le `.env` de l'espace
   membre. Puis `ESPACE_URL` dans `index.html`, une fois l'espace membre en ligne.
4. Le premier compte admin et l'équipe : remplir `scripts/equipe.json` (un objet par
   personne, `"role": "admin"` ou `"setter"`, `"equipe": "starter"`), puis :

   ```
   SUPABASE_URL="https://xxxx.supabase.co" SUPABASE_SERVICE_ROLE_KEY="…" node scripts/creer-comptes.mjs
   ```

   Chaque compte reçoit un mot de passe de 20 caractères tiré au hasard, jamais dérivé du
   prénom. Ils sont écrits dans `scripts/comptes.csv` (ignoré par git, jamais mis en ligne) :
   les distribuer, puis supprimer le fichier. Le script est relançable (`REINIT=1` pour
   reposer un mot de passe). La clé service_role ne s'écrit nulle part : elle se passe
   dans la commande.
5. Le rapport : `node scripts/cle-rapport.mjs` écrit la clé dans `scripts/rapport-cle.txt`
   (ignoré par git) et affiche la ligne SQL de son empreinte à passer dans le SQL Editor.
   Le lien est `https://<adresse du CRM>/rapport.html#<clé>`.
6. Avant d'ouvrir au public : `supabase/remise-a-zero.sql` efface les leads de test.

Mise en ligne : Vercel, sans build. `.vercelignore` exclut `scripts/`, `supabase/`,
`docs/`, `README.md` et `A-COMPLETER.md` : seuls `index.html`, `rapport.html`, `img/` et
`fonts/` sont servis.

## Retiré par rapport au CRM Sirius

- L'équipe **Skool** et tout son calendrier : réservations, rendez-vous, dispos, lien
  d'équipe, bascule Base44 / Skool, formule Skool.
- **Hermès** (ouverture des accès Skool).
- **Whop** et l'appel à 9,99 € : vivier opt-in, pastille « Payé », webhooks.
- L'offre **JVJ** (une seule page de vente ici).
- **Garantie et contrats** (liés aux 9,99 €).
- **Affiliate Consulting** (webhook des achats Base44) : le compte affilié d'ACE Club n'est
  pas connu — branchement possible plus tard, voir `A-COMPLETER.md`.
- **meta-vente** : n'envoyait à Meta que les ventes Skool ; les ventes Base44 n'étaient pas
  envoyées chez Sirius non plus. Pas repris.
- Le **parcours automatique** (dépôt de facture sans appel), déjà inutilisé chez Sirius.
- Les textes et prompts propres à Sirius (Kairo, prompt de secours, offre
  d'accompagnement) : la structure reste, le contenu est vide.
