-- Ce que le 3e passage d'INSTALLATION.sql ne doit pas changer (formules, dispenses, ventes, réglages).
select (select string_agg(code || '=' || n, ' ' order by code) from (select p.code, count(pm.module_id) n from plans p left join plan_modules pm on pm.plan_code = p.code group by p.code) x) as formules,
       (select count(*) from members where workshop_dispense) as dispenses,
       (select count(*) from members where guide_fait_at is not null) as guides_faits,
       (select string_agg(email || ':' || status || ':' || cash_collecte || ':' || commission, ' ' order by email) from leads) as leads,
       (select count(*) from invites) as invitations,
       (select titre from workshop_jours where jour = 10) as jour10,
       (select modules_avant_j3 || '/' || jour_deblocage from workshop_reglages) as reglage;
