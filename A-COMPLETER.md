# À compléter — CRM ACE Club

## Branchements (rien n'est en ligne)
- [ ] **Projet Supabase d'ACE Club** à créer, puis `supabase/INSTALLATION.sql` dans le SQL Editor
      (voir README, « Installer »). Désactiver « Allow new users to sign up ».
- [ ] `SUPABASE_URL` et `SUPABASE_ANON` en haut du script d'`index.html` `[À FOURNIR]`.
- [ ] `SUPABASE_URL` et `SUPABASE_ANON_KEY` dans `rapport.html` `[À FOURNIR]`.
- [ ] Les mêmes dans `reglages.js` de la page de vente, et dans le `.env` de l'espace membre.
- [ ] Page de vente : `COLONNES_SUIVI` peut passer à `true` dans `reglages.js` (les colonnes ref et
      utm_* existent dans la base) ; `COLONNE_SITUATION` est déjà à `true`.
- [ ] `ESPACE_URL` dans `index.html` : l'adresse de l'espace membre une fois en ligne `[À FOURNIR]`.
      Tant qu'elle est vide, le CRM ne fabrique pas de lien d'accès.
- [ ] Adresse du CRM (domaine Vercel) `[À FOURNIR]`, pour le lien du rapport.
- [ ] Clé du rapport : `node scripts/cle-rapport.mjs`, puis la ligne SQL affichée.
- [ ] Après les essais : `supabase/remise-a-zero.sql`.

## L'équipe
- [ ] Setters `[À FOURNIR : prénoms et adresses e-mail]` → `scripts/equipe.json` (`"role": "setter"`).
- [ ] Closers `[À FOURNIR]` : le CRM n'a qu'un rôle « setter » (celui qui prend le lead fait la
      vente). Si ACE Club a des closers distincts, dire comment le lead passe de l'un à l'autre.
- [ ] Administrateurs : `scripts/equipe.json` contient le compte admin de Martin (à confirmer) ;
      ajouter ceux d'ACE Club `[À FOURNIR]`.
- [ ] Un compte en vue réduite pour le client (onglets choisis) ? → `staff.vues`, exemple dans
      INSTALLATION.sql (section « vue réduite »).
- [ ] Horaires des setters `[À FOURNIR]` (la page de vente les affiche dans `HORAIRES`).

## L'offre
- [ ] Lien d'affiliation Base44 d'ACE Club `[À FOURNIR]` (utilisé par l'espace membre et le
      discours des setters ; le CRM ne l'affiche pas).
- [ ] À VALIDER : les trois offres et commissions reprises telles quelles du CRM Sirius
      (Mensuel Builder 200 $ / 10 %, Annuel Starter 250 $ / 12,5 %, Annuel Builder 475 $ / 15 %, confirmé par Martin le 23/11).
- [ ] À VALIDER : formules de l'espace membre (Mensuel Builder 1-8, Annuel Starter 1-14,
      Annuel Builder 1-20) et le rythme (1 module avant le jour 3, tout au jour 3).
- [ ] Offre d'accompagnement de fin de programme (`prochaines_etapes`, éteinte) `[À COMPLÉTER]`.

## Réglages du CRM (index.html)
- [ ] Récompenses du classement `[À FOURNIR]` → `RECOMPENSES` (vide = le bloc ne s'affiche pas ;
      les montants de l'ancien client ne sont pas repris).
- [ ] Seuils des cartes de taux (55 % de closing, 65 % de connection rate, repris tels quels) à confirmer.

## À décider
- [ ] **Alertes Slack** : nos templates n'en ont plus. Laquelle veut-on (nouveau lead non pris
      au bout de 10 min ? vente enregistrée ?) et sur quel canal `[À FOURNIR]` ?
- [ ] **Paiements Base44 (Affiliate Consulting)** : chez Sirius, un webhook rapprochait les achats
      réels des ventes déclarées. Retiré ici, faute de connaître le compte affilié d'ACE Club.
      Branchement possible plus tard (table d'événements + fonction + onglet).
- [ ] **Ventes envoyées à Meta (API Conversions)** : non reprises (chez Sirius, seules les ventes
      Skool partaient). À décider si le pixel d'ACE Club doit recevoir les ventes.
- [ ] Durée de conservation des leads et des enregistrements d'appels (page légale), région du
      projet Supabase.
