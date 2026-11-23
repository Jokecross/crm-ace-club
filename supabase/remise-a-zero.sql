-- =====================================================================
--  ACE Club — REMISE À ZÉRO DES DONNÉES DE TEST
--  À coller dans Supabase → SQL Editor → Run, AVANT l'ouverture au public.
--
--  Supprime tous les leads — vivier du jour, pipelines, relances,
--  archive, iClosed. Partent avec eux, en cascade : les factures, les
--  enregistrements d'appel et le journal d'activité. Supprime aussi les
--  invitations non utilisées et le compteur de visites.
--
--  Rien ne se récupère. Ne sont pas touchés : les comptes de l'équipe,
--  les élèves déjà inscrits, les tarifs, le contenu de l'espace membre
--  (modules, leçons, workshop) et les fichiers déjà dans les seaux.
-- =====================================================================

with efface as (
  delete from public.leads returning 1
)
select count(*) as leads_supprimes from efface;

with efface as (
  delete from public.invites where used_at is null returning 1
)
select count(*) as invitations_non_utilisees_supprimees from efface;

with efface as (
  delete from public.visites returning 1
)
select count(*) as visites_supprimees from efface;

-- Les fiches élèves qui pointaient vers un lead supprimé gardent leur
-- accès ; seul le lien vers le lead disparaît.
update public.members m
   set lead_id = null
 where m.lead_id is not null
   and not exists (select 1 from public.leads l where l.id = m.lead_id);

-- Le verdict. Tout doit afficher zéro.
select (select count(*) from public.leads)      as leads_restants,
       (select count(*) from public.invoices)   as factures_restantes,
       (select count(*) from public.lead_calls) as enregistrements_restants,
       (select count(*) from public.visites)    as visites_restantes;

-- ---------------------------------------------------------------------
-- Les fichiers
-- ---------------------------------------------------------------------
-- Postgres ne commande pas au stockage : les PDF de factures et les
-- enregistrements audio restent dans leurs seaux. Pour les vider :
-- Supabase → Storage → « factures » et « appels » → tout sélectionner →
-- Delete.
--
-- Les comptes et les fiches élèves de test se suppriment à la main :
-- Authentication → Users (la fiche members part avec le compte).
