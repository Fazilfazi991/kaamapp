-- KAAM skill catalog and normalized candidate skill records.
-- Run this after the existing migrations in the Supabase SQL Editor.
begin;

create table if not exists public.skill_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  icon_name text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.skills (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.skill_categories(id) on delete restrict,
  name text not null,
  slug text not null unique,
  is_custom boolean not null default false,
  is_approved boolean not null default true,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (category_id, name)
);

create table if not exists public.candidate_skills (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete restrict,
  is_primary boolean not null default false,
  experience_range text,
  skill_level text,
  uae_experience_range text,
  availability text,
  certificate_types text[] not null default '{}',
  other_certificate_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (candidate_id, skill_id),
  constraint candidate_skill_other_certificate_check check (
    other_certificate_name is null or char_length(btrim(other_certificate_name)) between 2 and 100
  )
);

create unique index if not exists candidate_skills_one_primary_idx
  on public.candidate_skills(candidate_id) where is_primary;
create index if not exists candidate_skills_skill_idx on public.candidate_skills(skill_id);

create table if not exists public.candidate_custom_skills (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  category_id uuid not null references public.skill_categories(id) on delete restrict,
  skill_name text not null,
  approval_status text not null default 'pending' check (approval_status in ('pending', 'approved', 'rejected')),
  approved_skill_id uuid references public.skills(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint candidate_custom_skills_name_check check (char_length(btrim(skill_name)) between 2 and 50),
  unique (candidate_id, category_id, skill_name)
);
create unique index if not exists candidate_custom_skills_normalized_name_idx
  on public.candidate_custom_skills(candidate_id, category_id, lower(btrim(skill_name)));

drop trigger if exists skill_categories_set_updated_at on public.skill_categories;
create trigger skill_categories_set_updated_at before update on public.skill_categories
for each row execute function public.set_updated_at();
drop trigger if exists skills_set_updated_at on public.skills;
create trigger skills_set_updated_at before update on public.skills
for each row execute function public.set_updated_at();
drop trigger if exists candidate_skills_set_updated_at on public.candidate_skills;
create trigger candidate_skills_set_updated_at before update on public.candidate_skills
for each row execute function public.set_updated_at();

alter table public.skill_categories enable row level security;
alter table public.skills enable row level security;
alter table public.candidate_skills enable row level security;
alter table public.candidate_custom_skills enable row level security;

drop policy if exists "skill_categories_read_active" on public.skill_categories;
create policy "skill_categories_read_active" on public.skill_categories for select to authenticated using (is_active or public.is_admin());
drop policy if exists "skill_categories_admin_manage" on public.skill_categories;
create policy "skill_categories_admin_manage" on public.skill_categories for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "skills_read_approved" on public.skills;
create policy "skills_read_approved" on public.skills for select to authenticated using ((is_active and is_approved) or public.is_admin());
drop policy if exists "skills_admin_manage" on public.skills;
create policy "skills_admin_manage" on public.skills for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "candidate_skills_own" on public.candidate_skills;
create policy "candidate_skills_own" on public.candidate_skills for all to authenticated using (candidate_id = auth.uid() or public.is_admin()) with check (candidate_id = auth.uid() or public.is_admin());
drop policy if exists "candidate_custom_skills_own_read" on public.candidate_custom_skills;
create policy "candidate_custom_skills_own_read" on public.candidate_custom_skills for select to authenticated using (candidate_id = auth.uid() or public.is_admin());
drop policy if exists "candidate_custom_skills_own_insert" on public.candidate_custom_skills;
create policy "candidate_custom_skills_own_insert" on public.candidate_custom_skills for insert to authenticated with check (candidate_id = auth.uid());
drop policy if exists "candidate_custom_skills_admin_manage" on public.candidate_custom_skills;
create policy "candidate_custom_skills_admin_manage" on public.candidate_custom_skills for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Public, employer-safe filter endpoint. It exposes no contact or document fields.
create or replace function public.search_candidates_by_skills(
  requested_category text default null,
  requested_skill text default null,
  primary_only boolean default false,
  requested_availability text default null
)
returns setof public.public_candidate_search
language sql stable security definer set search_path = public
as $$
  select pcs.*
  from public.public_candidate_search pcs
  where exists (
    select 1 from public.candidate_skills cs
    join public.skills s on s.id = cs.skill_id and s.is_active and s.is_approved
    join public.skill_categories sc on sc.id = s.category_id and sc.is_active
    where cs.candidate_id = pcs.id
      and (requested_category is null or lower(sc.name) = lower(requested_category))
      and (requested_skill is null or lower(s.name) = lower(requested_skill))
      and (not primary_only or cs.is_primary)
      and (requested_availability is null or lower(coalesce(cs.availability, '')) = lower(requested_availability))
  );
$$;
grant execute on function public.search_candidates_by_skills(text, text, boolean, text) to authenticated;

insert into public.skill_categories (name, slug, icon_name, sort_order) values
('Construction','construction','construction',1),('Electrical','electrical','bolt',2),('Plumbing & Sanitary','plumbing-sanitary','plumbing',3),('Mechanical & Technical','mechanical-technical','settings',4),('HVAC & Refrigeration','hvac-refrigeration','ac-unit',5),('Welding & Fabrication','welding-fabrication','hardware',6),('Driving','driving','directions-car',7),('Heavy Equipment Operation','heavy-equipment-operation','engineering',8),('Logistics & Warehouse','logistics-warehouse','inventory-2',9),('Cleaning & Housekeeping','cleaning-housekeeping','cleaning-services',10),('Security','security','security',11),('Hospitality & Restaurant','hospitality-restaurant','restaurant',12),('Retail & Sales','retail-sales','storefront',13),('Delivery & Courier','delivery-courier','delivery-dining',14),('Manufacturing & Factory','manufacturing-factory','factory',15),('Automotive','automotive','directions-car',16),('Facility Management','facility-management','apartment',17),('Domestic & Personal Services','domestic-personal-services','home',18),('Beauty & Salon','beauty-salon','content-cut',19),('Healthcare Support','healthcare-support','medical-services',20),('Office & Administration','office-administration','business-center',21),('IT & Electronics','it-electronics','computer',22),('Agriculture & Outdoor Work','agriculture-outdoor-work','yard',23),('Marine & Oil & Gas','marine-oil-gas','water',24),('General Labour','general-labour','handyman',25),('Other','other','more-horiz',26)
on conflict (slug) do update set name = excluded.name, icon_name = excluded.icon_name, sort_order = excluded.sort_order;

-- Seed catalog. Each row is category slug, skill name, stable skill slug, sort order.
insert into public.skills (category_id, name, slug, sort_order)
select sc.id, v.name, v.slug, v.sort_order
from (values
('construction','Carpenter','carpenter',1),('construction','Shuttering Carpenter','shuttering-carpenter',2),('construction','Furniture Carpenter','furniture-carpenter',3),('construction','Mason','mason',4),('construction','Block Mason','block-mason',5),('construction','Tile Mason','tile-mason',6),('construction','Plaster Mason','plaster-mason',7),('construction','Marble Installer','marble-installer',8),('construction','Painter','painter',9),('construction','Spray Painter','spray-painter',10),('construction','Steel Fixer','steel-fixer',11),('construction','Scaffolder','scaffolder',12),('construction','Gypsum Carpenter','gypsum-carpenter',13),('construction','False Ceiling Installer','false-ceiling-installer',14),('construction','Construction Helper','construction-helper',15),('construction','Site Supervisor','site-supervisor',16),
('electrical','Electrician','electrician',1),('electrical','Building Electrician','building-electrician',2),('electrical','Industrial Electrician','industrial-electrician',3),('electrical','Electrical Technician','electrical-technician',4),('electrical','Electrical Helper','electrical-helper',5),('electrical','Cable Technician','cable-technician',6),('electrical','Low-Voltage Technician','low-voltage-technician',7),('electrical','Solar Technician','solar-technician',8),('electrical','Generator Technician','generator-technician',9),
('plumbing-sanitary','Plumber','plumber',1),('plumbing-sanitary','Pipe Fitter','pipe-fitter',2),('plumbing-sanitary','Sanitary Technician','sanitary-technician',3),('plumbing-sanitary','Drainage Technician','drainage-technician',4),('plumbing-sanitary','Plumbing Helper','plumbing-helper',5),('plumbing-sanitary','Water Pump Technician','water-pump-technician',6),
('mechanical-technical','Mechanical Technician','mechanical-technician',1),('mechanical-technical','Mechanical Fitter','mechanical-fitter',2),('mechanical-technical','Machine Operator','machine-operator',3),('mechanical-technical','CNC Operator','cnc-operator',4),('mechanical-technical','Maintenance Technician','maintenance-technician',5),('mechanical-technical','Elevator Technician','elevator-technician',6),
('hvac-refrigeration','AC Technician','ac-technician',1),('hvac-refrigeration','HVAC Technician','hvac-technician',2),('hvac-refrigeration','HVAC Installer','hvac-installer',3),('hvac-refrigeration','Ductman','ductman',4),('hvac-refrigeration','Chiller Technician','chiller-technician',5),('hvac-refrigeration','Refrigeration Technician','refrigeration-technician',6),
('welding-fabrication','Welder','welder',1),('welding-fabrication','Arc Welder','arc-welder',2),('welding-fabrication','MIG Welder','mig-welder',3),('welding-fabrication','TIG Welder','tig-welder',4),('welding-fabrication','Aluminium Fabricator','aluminium-fabricator',5),('welding-fabrication','Steel Fabricator','steel-fabricator',6),
('driving','Light Vehicle Driver','light-vehicle-driver',1),('driving','Heavy Vehicle Driver','heavy-vehicle-driver',2),('driving','Bus Driver','bus-driver',3),('driving','Truck Driver','truck-driver',4),('driving','Delivery Driver','delivery-driver',5),('driving','Forklift Driver','forklift-driver',6),
('heavy-equipment-operation','Excavator Operator','excavator-operator',1),('heavy-equipment-operation','Crane Operator','crane-operator',2),('heavy-equipment-operation','Bulldozer Operator','bulldozer-operator',3),('heavy-equipment-operation','JCB Operator','jcb-operator',4),('heavy-equipment-operation','Loader Operator','loader-operator',5),('heavy-equipment-operation','Bobcat Operator','bobcat-operator',6),
('logistics-warehouse','Warehouse Helper','warehouse-helper',1),('logistics-warehouse','Warehouse Assistant','warehouse-assistant',2),('logistics-warehouse','Storekeeper','storekeeper',3),('logistics-warehouse','Picker and Packer','picker-and-packer',4),('logistics-warehouse','Loader and Unloader','loader-and-unloader',5),('logistics-warehouse','Inventory Assistant','inventory-assistant',6),('logistics-warehouse','Forklift Operator','forklift-operator',7),('logistics-warehouse','Warehouse Supervisor','warehouse-supervisor',8),
('cleaning-housekeeping','Cleaner','cleaner',1),('cleaning-housekeeping','Office Cleaner','office-cleaner',2),('cleaning-housekeeping','Building Cleaner','building-cleaner',3),('cleaning-housekeeping','Hotel Housekeeper','hotel-housekeeper',4),('cleaning-housekeeping','Room Attendant','room-attendant',5),('cleaning-housekeeping','Deep Cleaning Worker','deep-cleaning-worker',6),('cleaning-housekeeping','Window Cleaner','window-cleaner',7),
('security','Security Guard','security-guard',1),('security','CCTV Operator','cctv-operator',2),('security','Security Supervisor','security-supervisor',3),('security','Watchman','watchman',4),('security','Lifeguard','lifeguard',5),
('hospitality-restaurant','Waiter','waiter',1),('hospitality-restaurant','Waitress','waitress',2),('hospitality-restaurant','Barista','barista',3),('hospitality-restaurant','Kitchen Helper','kitchen-helper',4),('hospitality-restaurant','Chef','chef',5),('hospitality-restaurant','Cook','cook',6),('hospitality-restaurant','Hotel Receptionist','hotel-receptionist',7),
('retail-sales','Salesman','salesman',1),('retail-sales','Saleswoman','saleswoman',2),('retail-sales','Retail Sales Associate','retail-sales-associate',3),('retail-sales','Cashier','cashier',4),('retail-sales','Merchandiser','merchandiser',5),('retail-sales','Store Supervisor','store-supervisor',6),
('delivery-courier','Bike Delivery Rider','bike-delivery-rider',1),('delivery-courier','Car Delivery Driver','car-delivery-driver',2),('delivery-courier','Courier','courier',3),('delivery-courier','Food Delivery Rider','food-delivery-rider',4),('delivery-courier','Parcel Delivery Driver','parcel-delivery-driver',5),
('manufacturing-factory','Factory Worker','factory-worker',1),('manufacturing-factory','Production Worker','production-worker',2),('manufacturing-factory','Assembly Line Worker','assembly-line-worker',3),('manufacturing-factory','Packing Worker','packing-worker',4),('manufacturing-factory','Quality Checker','quality-checker',5),
('automotive','Auto Mechanic','auto-mechanic',1),('automotive','Car Electrician','car-electrician',2),('automotive','Diesel Mechanic','diesel-mechanic',3),('automotive','Auto AC Technician','auto-ac-technician',4),('automotive','Tyre Technician','tyre-technician',5),('automotive','Car Painter','car-painter',6),
('facility-management','Facility Technician','facility-technician',1),('facility-management','Multi Technician','multi-technician',2),('facility-management','Building Maintenance Technician','building-maintenance-technician',3),('facility-management','Handyman','handyman',4),('facility-management','BMS Operator','bms-operator',5),('facility-management','Gardener','gardener',6),
('domestic-personal-services','Housemaid','housemaid',1),('domestic-personal-services','Nanny','nanny',2),('domestic-personal-services','Caregiver','caregiver',3),('domestic-personal-services','Cook','domestic-cook',4),('domestic-personal-services','Personal Driver','personal-driver',5),('domestic-personal-services','Housekeeper','housekeeper',6),
('beauty-salon','Barber','barber',1),('beauty-salon','Hairdresser','hairdresser',2),('beauty-salon','Beautician','beautician',3),('beauty-salon','Nail Technician','nail-technician',4),('beauty-salon','Makeup Artist','makeup-artist',5),('beauty-salon','Spa Therapist','spa-therapist',6),
('healthcare-support','Nurse','nurse',1),('healthcare-support','Assistant Nurse','assistant-nurse',2),('healthcare-support','Caregiver','healthcare-caregiver',3),('healthcare-support','Nursing Assistant','nursing-assistant',4),('healthcare-support','Dental Assistant','dental-assistant',5),('healthcare-support','Medical Receptionist','medical-receptionist',6),
('office-administration','Office Assistant','office-assistant',1),('office-administration','Data Entry Operator','data-entry-operator',2),('office-administration','Receptionist','receptionist',3),('office-administration','Administrative Assistant','administrative-assistant',4),('office-administration','Document Controller','document-controller',5),('office-administration','Customer Service Executive','customer-service-executive',6),
('it-electronics','Computer Technician','computer-technician',1),('it-electronics','Mobile Phone Technician','mobile-phone-technician',2),('it-electronics','CCTV Technician','cctv-technician',3),('it-electronics','Network Technician','network-technician',4),('it-electronics','IT Support Technician','it-support-technician',5),('it-electronics','Electronics Technician','electronics-technician',6),
('agriculture-outdoor-work','Farm Worker','farm-worker',1),('agriculture-outdoor-work','Gardener','agriculture-gardener',2),('agriculture-outdoor-work','Landscaper','landscaper',3),('agriculture-outdoor-work','Irrigation Technician','irrigation-technician',4),('agriculture-outdoor-work','Nursery Worker','nursery-worker',5),
('marine-oil-gas','Rigger','rigger',1),('marine-oil-gas','Roustabout','roustabout',2),('marine-oil-gas','Pipe Fitter','marine-pipe-fitter',3),('marine-oil-gas','Offshore Helper','offshore-helper',4),('marine-oil-gas','Marine Electrician','marine-electrician',5),('marine-oil-gas','Marine Mechanic','marine-mechanic',6),
('general-labour','General Helper','general-helper',1),('general-labour','General Labourer','general-labourer',2),('general-labour','Loading Worker','loading-worker',3),('general-labour','Packing Helper','packing-helper',4),('general-labour','Site Helper','site-helper',5),('general-labour','Factory Helper','factory-helper',6),
('other','Other Skilled Worker','other-skilled-worker',1),('other','Other Technical Worker','other-technical-worker',2),('other','Other Service Worker','other-service-worker',3),('other','Other General Worker','other-general-worker',4)
) as v(category_slug, name, slug, sort_order)
join public.skill_categories sc on sc.slug = v.category_slug
on conflict (slug) do update set name = excluded.name, category_id = excluded.category_id, sort_order = excluded.sort_order, is_active = true;

notify pgrst, 'reload schema';
commit;
