-- =====================================================================
--  Scénario de test de la base ACE Club, sur un Postgres LOCAL seulement
--  (voir docs/TESTS.md, lancé depuis docs/tests/). Jamais sur le projet Supabase en service : il
--  crée des comptes, des leads et des modules de démonstration.
--
--  Chaque vérification est un `assert` : la première qui échoue arrête
--  tout (psql -v ON_ERROR_STOP=1).
-- =====================================================================

\set ON_ERROR_STOP 1
\pset footer off

-- Les personnes du test (identifiants fixes pour s'y retrouver).
\set admin   '''00000000-0000-4000-a000-000000000001'''
\set setter  '''00000000-0000-4000-a000-000000000002'''
\set setter2 '''00000000-0000-4000-a000-000000000003'''
\set eleve   '''00000000-0000-4000-a000-000000000004'''

-- Les jours du CRM sont ceux de Paris, quel que soit le fuseau de la machine.
\set auj '(now() at time zone ''Europe/Paris'')::date'

-- Se mettre dans la peau de quelqu'un, comme le ferait PostgREST.
create or replace function pg_temp.etre(p_role text, p_sub uuid default null) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('role', p_role, 'sub', p_sub)::text, false);
  execute format('set role %I', p_role);
end $$;

\echo '--- 0. L''équipe : un admin, deux setters (comme scripts/creer-comptes.mjs)'
insert into auth.users (id, email) values
  (:admin,   'admin@test.local'),
  (:setter,  'setter1@test.local'),
  (:setter2, 'setter2@test.local');
insert into public.staff (user_id, first_name, role, equipe, equipes) values
  (:admin,   'Admin',   'admin',  'starter', '{starter}'),
  (:setter,  'Setter',  'setter', 'starter', '{starter}'),
  (:setter2, 'Setter2', 'setter', 'starter', '{starter}');
-- Le déclencheur staff_vers_membre leur ouvre aussi l'espace membre.
do $$ begin
  assert (select count(*) from public.members where role in ('admin','setter')) = 3,
    'les comptes du CRM doivent avoir une fiche members';
end $$;

\echo '--- 0 bis. Le contenu de démonstration : une intro et 20 modules d''une leçon'
insert into public.modules (position, title, is_intro) values (0, 'Bienvenue (démo)', true);
insert into public.modules (position, title)
select n, 'Module ' || n || ' (démo)' from generate_series(1, 20) n;
insert into public.lessons (module_id, position, title)
select id, 1, 'Leçon de ' || title from public.modules;
select p.code, p.label, count(pm.module_id) as modules,
       min(m.position) as du, max(m.position) as au
  from public.plans p
  left join public.plan_modules pm on pm.plan_code = p.code
  left join public.modules m on m.id = pm.module_id
 group by p.code, p.label, p.rank order by p.rank;
do $$ begin
  assert (select count(*) from public.plan_modules where plan_code = 'mensuel') = 8, 'Mensuel Builder = modules 1 à 8';
  assert (select count(*) from public.plan_modules where plan_code = 'annuel') = 14, 'Annuel Starter = modules 1 à 14';
  assert (select count(*) from public.plan_modules where plan_code = 'annuel_builder') = 20, 'Annuel Builder = modules 1 à 20';
  assert (select count(*) from public.workshop_jours) = 10, 'le workshop a 10 jours';
end $$;

\echo '--- 1. La page de vente dépose un lead (clé anon)'
select pg_temp.etre('anon');
insert into public.leads (first_name, last_name, email, phone, page_url, source, situation)
values ('Camille', 'Test', 'camille@test.local', '+33612345678',
        'https://exemple.test/?utm_source=tiktok&utm_campaign=c1', 'ace-club', 'Étudiant');
select public.visite_compter('11111111-1111-4111-a111-111111111111', 'tiktok');
select public.visite_compter('11111111-1111-4111-a111-111111111111', 'tiktok');
-- Interdit : lire les leads, ou en déposer un déjà attribué.
do $$ begin
  begin
    perform count(*) from public.leads;
    raise exception 'anon ne doit pas pouvoir lire leads';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.leads (first_name, last_name, email, phone, source, setter_id)
    values ('X', 'Y', 'x@test.local', '+33600000000', 'ace-club', '00000000-0000-4000-a000-000000000002');
    raise exception 'anon ne doit pas pouvoir attribuer un lead';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.leads (first_name, last_name, email, phone, source, status)
    values ('X', 'Y', 'x@test.local', '+33600000000', 'ace-club', 'yearly_builder');
    raise exception 'anon ne doit pas pouvoir déposer une vente';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

\echo '--- 2. Le setter le voit dans les Leads du jour, et le prend'
select pg_temp.etre('authenticated', :setter);
select first_name, situation, source, vivier, equipe, status, setter_id is null as libre,
       public.origine_lead(l) as origine
  from public.leads l where vivier = 'formulaire' and setter_id is null;
do $$ begin
  assert (select count(*) from public.leads where vivier = 'formulaire' and setter_id is null
           and situation = 'Étudiant' and source = 'ace-club') = 1, 'le setter doit voir le lead libre';
end $$;
-- La prise : le premier qui écrit son nom l'a (même requête que le CRM).
update public.leads set setter_id = auth.uid(), called_at = now()
 where email = 'camille@test.local' and setter_id is null;
do $$ begin
  assert (select dials from public.leads where email = 'camille@test.local') = 1,
    'prendre un lead compte le premier appel';
end $$;
reset role;

\echo '--- 3. Le second setter arrive trop tard'
select pg_temp.etre('authenticated', :setter2);
update public.leads set setter_id = auth.uid()
 where email = 'camille@test.local' and setter_id is null;
do $$ begin
  assert (select setter_id from public.leads where email = 'camille@test.local')
         = '00000000-0000-4000-a000-000000000002', 'le lead reste au premier setter';
end $$;
reset role;

\echo '--- 4. Vente Annuel Builder : tarif et commission posés par la base'
select pg_temp.etre('authenticated', :setter);
-- Le navigateur envoie un montant farfelu : la base l'ignore.
update public.leads set status = 'yearly_builder', cash_collecte = 1, commission = 999
 where email = 'camille@test.local';
select first_name, status, cash_collecte, commission, closed_at is not null as vente_datee
  from public.leads where email = 'camille@test.local';
do $$ begin
  assert (select cash_collecte from public.leads where email = 'camille@test.local') = 475, 'Annuel Builder = 475 $';
  assert (select commission from public.leads where email = 'camille@test.local') = 71.25, 'commission 15 % = 71,25 $';
end $$;
select public.crm_stats(null, null, auth.uid(), 'formulaire', 'starter') as mes_chiffres;
select public.classement_setters(:auj, :auj, 'starter') -> 'lignes' -> 0 as premier_du_classement;
do $$ begin
  assert (public.classement_setters((now() at time zone 'Europe/Paris')::date, (now() at time zone 'Europe/Paris')::date, 'starter')
          -> 'lignes' -> 0 ->> 'cash')::numeric = 475, 'le setter est premier du classement avec 475 $';
end $$;
reset role;

\echo '--- 5. Le setter crée l''accès espace membre'
select pg_temp.etre('authenticated', :setter);
select public.creer_acces_espace((select id from public.leads where email = 'camille@test.local')) as acces \gset
\echo :acces
do $$
declare a json; b json;
begin
  a := public.creer_acces_espace((select id from public.leads where email = 'camille@test.local'));
  assert a->>'plan_code' = 'annuel_builder', 'yearly_builder → formule annuel_builder';
  assert a->>'plan_label' = 'Annuel Builder', 'libellé Annuel Builder';
  b := public.creer_acces_espace((select id from public.leads where email = 'camille@test.local'));
  assert a->>'token' = b->>'token', 'rappeler sans changement renvoie la même invitation';
  assert (select invite_token::text from public.leads where email = 'camille@test.local') = a->>'token',
    'le lead garde son invitation';
end $$;
reset role;

\echo '--- 5 bis. Le second setter ne peut pas créer l''accès d''un lead qui n''est pas le sien'
select pg_temp.etre('authenticated', :setter2);
do $$ begin
  begin
    perform public.creer_acces_espace((select id from public.leads where email = 'camille@test.local'));
    raise exception 'un autre setter ne doit pas pouvoir créer cet accès';
  exception when others then
    if sqlerrm not like '%introuvable%' and sqlerrm not like '%pas le tien%' then raise; end if;
  end;
end $$;
reset role;

\echo '--- 6. L''élève accepte l''invitation (ce que fait api/invite-accept, clé service_role)'
-- 6a. auth.admin.createUser
insert into auth.users (id, email, email_confirmed_at) values (:eleve, 'camille@test.local', now());
-- 6b. lecture de l'invitation, puis fiche members avec sa formule
select pg_temp.etre('service_role');
insert into public.members (id, email, first_name, last_name, plan_code)
select :eleve, 'camille@test.local', 'Camille', 'Test', i.plan_code
  from public.invites i
 where i.token = (select invite_token from public.leads where email = 'camille@test.local')
   and i.used_at is null and i.expires_at > now()
on conflict (id) do update set plan_code = excluded.plan_code;
-- 6c. le jeton est brûlé
update public.invites set used_at = now(), used_by = :eleve
 where token = (select invite_token from public.leads where email = 'camille@test.local');
reset role;
do $$ begin
  assert (select plan_code from public.members where email = 'camille@test.local') = 'annuel_builder', 'formule Annuel Builder';
  assert (select lead_id from public.members where email = 'camille@test.local')
         = (select id from public.leads where email = 'camille@test.local'), 'la fiche élève pointe vers son lead';
end $$;

\echo '--- 7. L''élève, jour 1 : l''intro, puis le module 1 seulement'
select pg_temp.etre('authenticated', :eleve);
select public.mon_etat_workshop() as etat;
select jour, titre, ouvert, ouvre_le is not null as compte_a_rebours from public.mon_workshop() where jour <= 3;
do $$ begin
  assert public.workshop_jour(auth.uid()) = 1, 'jour 1 dès l''inscription';
  assert (select ouvert from public.mon_workshop() where jour = 1), 'le jour 1 est ouvert';
  assert (select titre from public.mon_workshop() where jour = 1) = 'Ton offre et ta cible', 'titre du jour 1';
  assert not (select ouvert from public.mon_workshop() where jour = 2), 'le jour 2 attend minuit';
  assert (select count(*) from public.my_modules()) = 21, 'l''intro et les 20 modules de sa formule';
  assert (select count(*) from public.my_modules() where unlocked and not is_intro) = 0,
    'tant que le guide n''est pas fini, le programme est fermé';
end $$;
select public.guide_termine();   -- la fin du guide coche l'introduction
select "position", title, unlocked from public.my_modules() order by is_intro desc, "position" limit 4;
do $$ begin
  assert (select count(*) from public.my_modules() where unlocked and not is_intro) = 1,
    'avant le jour 3, un seul module (réglage modules_avant_j3 = 1)';
  assert (select count(*) from public.lessons l join public.modules m on m.id = l.module_id
           where m.position = 15) = 0, 'une leçon fermée ne part pas dans le navigateur';
end $$;
reset role;

\echo '--- 8. Deux nuits plus tard (jour 3) : les 20 modules s''ouvrent'
update public.members set activated_at = activated_at - interval '2 days' where id = :eleve;
select pg_temp.etre('authenticated', :eleve);
do $$ begin
  assert public.workshop_jour(auth.uid()) = 3, 'jour 3 après deux minuits';
  assert (select count(*) from public.my_modules() where unlocked and not is_intro) = 20,
    'Annuel Builder : les modules 1 à 20 ouverts au jour 3';
  assert (select count(*) from public.lessons l join public.modules m on m.id = l.module_id
           where m.position = 15) = 1, 'la leçon du module 15 est lisible';
end $$;
select count(*) filter (where unlocked and not is_intro) as modules_ouverts from public.my_modules();
reset role;

\echo '--- 9. Le jour 10 est le dernier'
update public.members set activated_at = activated_at - interval '20 days' where id = :eleve;
select pg_temp.etre('authenticated', :eleve);
do $$ begin
  assert public.workshop_jour(auth.uid()) = 10, 'le workshop plafonne au jour 10';
  assert (select count(*) from public.mon_workshop() where ouvert) = 10, 'les 10 jours ouverts';
end $$;
reset role;

\echo '--- 10. L''offre change après l''inscription : la formule suit'
select pg_temp.etre('authenticated', :setter);
update public.leads set status = 'yearly' where email = 'camille@test.local';
do $$
declare a json;
begin
  assert (select commission from public.leads where email = 'camille@test.local') = 31.25, 'Annuel Starter : 31,25 $';
  a := public.creer_acces_espace((select id from public.leads where email = 'camille@test.local'));
  assert (a->>'deja_inscrit')::boolean, 'l''élève est déjà inscrit';
  assert a->>'plan_code' = 'annuel', 'yearly → annuel';
end $$;
reset role;
select pg_temp.etre('authenticated', :eleve);
do $$ begin
  assert (select count(*) from public.my_modules() where not is_intro) = 14, 'Annuel Starter : 14 modules';
end $$;
reset role;

\echo '--- 11. Un lien pas encore utilisé suit lui aussi l''offre (Mensuel Builder)'
select pg_temp.etre('anon');
insert into public.leads (first_name, last_name, email, phone, page_url, source, situation)
values ('Lou', 'Test', 'lou@test.local', '+33698765432', 'https://exemple.test/?ref=demo', 'ace-club', 'Salarié');
reset role;
select pg_temp.etre('authenticated', :setter);
update public.leads set setter_id = auth.uid() where email = 'lou@test.local' and setter_id is null;
update public.leads set status = 'yearly' where email = 'lou@test.local';
do $$
declare a json; b json;
begin
  a := public.creer_acces_espace((select id from public.leads where email = 'lou@test.local'));
  assert a->>'plan_code' = 'annuel', 'yearly → annuel';
  update public.leads set status = 'monthly' where email = 'lou@test.local';
  assert (select commission from public.leads where email = 'lou@test.local') = 20.00, 'Mensuel Builder : 20 $';
  b := public.creer_acces_espace((select id from public.leads where email = 'lou@test.local'));
  assert b->>'plan_code' = 'mensuel', 'monthly → mensuel';
  assert a->>'token' <> b->>'token', 'nouveau lien pour la nouvelle formule';
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.invites
           where label like 'Lou Test%' ) = 1, 'l''ancien lien non utilisé est supprimé';
end $$;

\echo '--- 12. Chiffres de l''administrateur : Sources et rapport'
select pg_temp.etre('authenticated', :admin);
select public.stats_sources(:auj, :auj) as sources;
do $$ declare s json := public.stats_sources((now() at time zone 'Europe/Paris')::date, (now() at time zone 'Europe/Paris')::date);
begin
  assert (s -> 'total' ->> 'visiteurs')::int = 1, 'un visiteur compté (deux vues)';
  assert (s -> 'total' ->> 'vues')::int = 2, 'deux vues';
  assert (s -> 'total' ->> 'formulaires')::int = 2, 'deux formulaires';
  assert (s -> 'total' ->> 'ventes')::int = 2, 'deux ventes';
end $$;
select public.crm_stats(null, null, null, 'formulaire', 'starter') as equipe;
reset role;
-- Le rapport sans connexion : une clé de test, son empreinte seule en base.
insert into public.cles_integration (nom, empreinte)
values ('rapport', encode(extensions.digest('cle-de-test-locale', 'sha256'), 'hex'))
on conflict (nom) do update set empreinte = excluded.empreinte;
select pg_temp.etre('anon');
select public.rapport_pages('cle-de-test-locale', :auj, :auj) -> 'total' as rapport_total;
select public.rapport_pages('cle-de-test-locale', :auj, :auj) -> 'formules' as rapport_formules;
do $$ begin
  begin
    perform public.rapport_pages('mauvaise-cle', (now() at time zone 'Europe/Paris')::date, (now() at time zone 'Europe/Paris')::date);
    raise exception 'une mauvaise clé doit être refusée';
  exception when invalid_authorization_specification then null;
  end;
end $$;
reset role;

\echo '--- 13. formules_recalculer() remet les formules d''aplomb'
delete from public.plan_modules where plan_code = 'annuel';
select * from public.formules_recalculer();
do $$ begin
  assert (select count(*) from public.plan_modules where plan_code = 'annuel') = 14, 'Annuel Starter recalculé';
end $$;

\echo 'SCÉNARIO OK'
