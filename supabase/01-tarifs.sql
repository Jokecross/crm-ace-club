-- Tarifs d'ACE Club (23/11/2026) : 200 / 250 / 475 $, 10 / 12,5 / 15 %.
-- Déjà dans INSTALLATION.sql. À passer sur la base en ligne. Rejouable.

create or replace function public.forcer_tarif()
returns trigger
language plpgsql
as $$
begin
  new.cash_collecte := case new.status::text
    when 'monthly'        then 200
    when 'yearly'         then 250
    when 'yearly_builder' then 475
    else 0
  end;
  new.commission := case new.status::text
    when 'monthly'        then round(new.cash_collecte * 0.10, 2)
    when 'yearly'         then round(new.cash_collecte * 0.125, 2)
    when 'yearly_builder' then round(new.cash_collecte * 0.15, 2)
    else 0
  end;
  return new;
end;
$$;

-- Recalcule les ventes déjà enregistrées (le déclencheur fait le calcul).
update public.leads set cash_collecte = cash_collecte
 where status::text in ('monthly', 'yearly', 'yearly_builder');

-- Contrôle : lit la fonction réellement en place.
select case when d like '%then 200%' and d like '%then 250%' and d like '%then 475%' then 'TARIFS OK : 200 / 250 / 475' else 'ERREUR' end as resultat,
       (select string_agg(status::text || ' ' || cash_collecte || ' -> ' || commission, ', ') from public.leads where status::text in ('monthly','yearly','yearly_builder')) as ventes
from (select pg_get_functiondef('public.forcer_tarif()'::regprocedure) as d) x;
