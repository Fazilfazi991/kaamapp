-- KAAM Phase 1: additive canonical role and competency taxonomy.
-- This migration intentionally does not alter the legacy skill_categories,
-- skills, candidate_skills, employer_hiring_requirements, or verification flow.
-- Run through the normal Supabase migration process; do not paste into production
-- until the accompanying taxonomy review is approved.

begin;

create extension if not exists pg_trgm;

create or replace function public.kaam_normalize_catalog_text(value text)
returns text
language sql
immutable
strict
parallel safe
as $$
  select trim(regexp_replace(lower(regexp_replace(value, '[^[:alnum:]]+', ' ', 'g')), '\\s+', ' ', 'g'));
$$;

create table if not exists public.industries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint industries_name_unique unique (name),
  constraint industries_slug_unique unique (slug),
  constraint industries_slug_format check (slug = public.kaam_normalize_catalog_text(slug)::text or slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.job_categories (
  id uuid primary key default gen_random_uuid(),
  industry_id uuid not null references public.industries(id) on delete restrict,
  name text not null,
  slug text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_categories_industry_slug_unique unique (industry_id, slug),
  constraint job_categories_industry_name_unique unique (industry_id, name),
  constraint job_categories_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.job_roles (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.job_categories(id) on delete restrict,
  name text not null,
  slug text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_roles_category_slug_unique unique (category_id, slug),
  constraint job_roles_category_name_unique unique (category_id, name),
  constraint job_roles_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.job_role_aliases (
  id uuid primary key default gen_random_uuid(),
  job_role_id uuid not null references public.job_roles(id) on delete cascade,
  alias text not null,
  normalized_alias text generated always as (public.kaam_normalize_catalog_text(alias)) stored,
  created_at timestamptz not null default now(),
  constraint job_role_aliases_alias_not_blank check (length(btrim(alias)) > 0),
  constraint job_role_aliases_normalized_unique unique (normalized_alias)
);

create table if not exists public.competency_skills (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint competency_skills_name_unique unique (name),
  constraint competency_skills_slug_unique unique (slug),
  constraint competency_skills_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.job_role_skills (
  job_role_id uuid not null references public.job_roles(id) on delete cascade,
  competency_skill_id uuid not null references public.competency_skills(id) on delete restrict,
  relevance smallint not null default 50 check (relevance between 1 and 100),
  is_core boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (job_role_id, competency_skill_id)
);

create table if not exists public.legacy_role_mappings (
  id uuid primary key default gen_random_uuid(),
  source_type text not null,
  source_id uuid,
  source_value text not null,
  canonical_job_role_id uuid references public.job_roles(id) on delete restrict,
  mapping_confidence numeric(4,3) not null check (mapping_confidence between 0 and 1),
  mapping_method text not null check (mapping_method in ('exact_name', 'exact_alias', 'manual', 'unmapped')),
  reviewed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint legacy_role_mappings_source_unique unique (source_type, source_id),
  constraint legacy_role_mappings_unmapped_consistency check (
    (mapping_method = 'unmapped' and canonical_job_role_id is null) or
    (mapping_method <> 'unmapped' and canonical_job_role_id is not null)
  )
);

create index if not exists job_categories_industry_active_idx on public.job_categories(industry_id, active, sort_order);
create index if not exists job_roles_category_active_idx on public.job_roles(category_id, active, sort_order);
create index if not exists job_roles_active_name_trgm_idx on public.job_roles using gin (name gin_trgm_ops) where active;
create index if not exists job_role_aliases_normalized_trgm_idx on public.job_role_aliases using gin (normalized_alias gin_trgm_ops);
create index if not exists job_role_skills_skill_idx on public.job_role_skills(competency_skill_id);
create index if not exists competency_skills_active_name_trgm_idx on public.competency_skills using gin (name gin_trgm_ops) where active;
create index if not exists legacy_role_mappings_role_idx on public.legacy_role_mappings(canonical_job_role_id);

drop trigger if exists industries_set_updated_at on public.industries;
create trigger industries_set_updated_at before update on public.industries for each row execute function public.set_updated_at();
drop trigger if exists job_categories_set_updated_at on public.job_categories;
create trigger job_categories_set_updated_at before update on public.job_categories for each row execute function public.set_updated_at();
drop trigger if exists job_roles_set_updated_at on public.job_roles;
create trigger job_roles_set_updated_at before update on public.job_roles for each row execute function public.set_updated_at();
drop trigger if exists competency_skills_set_updated_at on public.competency_skills;
create trigger competency_skills_set_updated_at before update on public.competency_skills for each row execute function public.set_updated_at();
drop trigger if exists legacy_role_mappings_set_updated_at on public.legacy_role_mappings;
create trigger legacy_role_mappings_set_updated_at before update on public.legacy_role_mappings for each row execute function public.set_updated_at();

alter table public.industries enable row level security;
alter table public.job_categories enable row level security;
alter table public.job_roles enable row level security;
alter table public.job_role_aliases enable row level security;
alter table public.competency_skills enable row level security;
alter table public.job_role_skills enable row level security;
alter table public.legacy_role_mappings enable row level security;

-- Catalog reads are available to signed-in candidate and employer clients.
-- Admins may manage master data; service_role bypasses RLS for controlled imports.
drop policy if exists "industries_catalog_read" on public.industries;
drop policy if exists "industries_admin_manage" on public.industries;
drop policy if exists "job_categories_catalog_read" on public.job_categories;
drop policy if exists "job_categories_admin_manage" on public.job_categories;
drop policy if exists "job_roles_catalog_read" on public.job_roles;
drop policy if exists "job_roles_admin_manage" on public.job_roles;
drop policy if exists "job_role_aliases_catalog_read" on public.job_role_aliases;
drop policy if exists "job_role_aliases_admin_manage" on public.job_role_aliases;
drop policy if exists "competency_skills_catalog_read" on public.competency_skills;
drop policy if exists "competency_skills_admin_manage" on public.competency_skills;
drop policy if exists "job_role_skills_catalog_read" on public.job_role_skills;
drop policy if exists "job_role_skills_admin_manage" on public.job_role_skills;
drop policy if exists "legacy_role_mappings_admin_only" on public.legacy_role_mappings;
create policy "industries_catalog_read" on public.industries for select to authenticated using (active or public.is_admin());
create policy "industries_admin_manage" on public.industries for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "job_categories_catalog_read" on public.job_categories for select to authenticated using (active or public.is_admin());
create policy "job_categories_admin_manage" on public.job_categories for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "job_roles_catalog_read" on public.job_roles for select to authenticated using (active or public.is_admin());
create policy "job_roles_admin_manage" on public.job_roles for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "job_role_aliases_catalog_read" on public.job_role_aliases for select to authenticated using (public.is_admin() or exists (select 1 from public.job_roles r where r.id = job_role_id and r.active));
create policy "job_role_aliases_admin_manage" on public.job_role_aliases for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "competency_skills_catalog_read" on public.competency_skills for select to authenticated using (active or public.is_admin());
create policy "competency_skills_admin_manage" on public.competency_skills for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "job_role_skills_catalog_read" on public.job_role_skills for select to authenticated using (public.is_admin() or exists (select 1 from public.job_roles r join public.competency_skills s on s.id = competency_skill_id where r.id = job_role_id and r.active and s.active));
create policy "job_role_skills_admin_manage" on public.job_role_skills for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "legacy_role_mappings_admin_only" on public.legacy_role_mappings for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant select on public.industries, public.job_categories, public.job_roles, public.job_role_aliases, public.competency_skills, public.job_role_skills to authenticated;

-- Industry and category seeds. Role strings are expanded below into canonical records.
with industry_seed(slug, name, sort_order) as (values
 ('food-beverage','Restaurant / Food & Beverage',10),('hotel-hospitality','Hotel / Hospitality',20),('catering','Catering',30),('cleaning','Cleaning Services',40),('housekeeping','Housekeeping',50),('facility-management','Facility Management',60),('construction-civil','Construction / Civil',70),('mep','MEP',80),('carpentry-joinery','Carpentry / Joinery',90),('painting','Painting',100),('welding-fabrication','Welding / Fabrication',110),('steel-structural','Steel / Structural',120),('manufacturing-factory','Manufacturing / Factory',130),('warehouse-logistics','Warehouse / Logistics',140),('delivery-courier','Delivery / Courier',150),('driving-transport','Driving / Transportation',160),('automotive-garage','Automotive / Garage',170),('retail','Retail',180),('supermarket','Supermarket / Hypermarket',190),('sales-customer-service','Sales / Customer Service',200),('security','Security',210),('salon-beauty','Salon / Beauty',220),('laundry','Laundry',230),('agriculture','Agriculture',240),('landscaping','Landscaping',250),('healthcare-support','Healthcare Support',260),('office-administration','Office / Administration',270),('maintenance','Maintenance',280),('general-labour','General Labour / Helpers',290),('marine-oil-gas','Marine / Oil & Gas Support',300),('events','Events / Entertainment Support',310),('domestic-services','Domestic Services',320)
) insert into public.industries(name, slug, sort_order)
select name, slug, sort_order from industry_seed on conflict (slug) do update set name = excluded.name, sort_order = excluded.sort_order, active = true;

with category_seed(industry_slug, slug, name, sort_order, roles) as (values
 ('food-beverage','kitchen','Kitchen',10,'Executive Chef|Head Chef|Sous Chef|Chef de Partie|Demi Chef de Partie|Commis Chef|Assistant Cook|General Cook|Indian Cook|North Indian Cook|South Indian Cook|Kerala Cook|Arabic Cook|Chinese Cook|Continental Cook|Pakistani Cook|Bengali Cook|Filipino Cook|Tandoor Cook|Tandoor Helper|Shawarma Maker|Grill Cook|BBQ Cook|Biryani Cook|Curry Cook|Porotta Maker|Chapati Maker|Roti Maker|Dosa Maker|Idiyappam Maker|Appam Maker'),
 ('food-beverage','bakery','Bakery & Pastry',20,'Bakery Chef|Baker|Pastry Chef|Cake Decorator|Cake Maker|Dessert Chef|Chocolate Maker'),
 ('food-beverage','quick-service','Quick Service',30,'Pizza Maker|Burger Maker|Sandwich Maker|Fried Chicken Cook|Snack Maker|Counter Cook'),
 ('food-beverage','beverage','Beverage',40,'Juice Maker|Tea Maker|Karak Maker|Barista|Mocktail Maker'),
 ('food-beverage','front-of-house','Front of House',50,'Waiter / Server|Captain|Restaurant Supervisor|Restaurant Manager|Cashier|Host / Hostess|Food Runner|Busser|Order Taker|Counter Staff'),
 ('food-beverage','stewarding','Cleaning & Stewarding',60,'Kitchen Helper|Kitchen Steward|Dishwasher|Restaurant Cleaner'),
 ('food-beverage','restaurant-delivery','Restaurant Delivery',70,'Food Delivery Rider|Food Delivery Driver|Restaurant Delivery Coordinator'),
 ('hotel-hospitality','hotel-housekeeping','Hotel Housekeeping',10,'Room Attendant|Housekeeping Attendant|Housekeeping Supervisor|Public Area Cleaner|Hotel Cleaner'),
 ('hotel-hospitality','guest-services','Guest Services',20,'Bell Attendant|Concierge|Doorman|Valet Attendant|Guest Service Agent'),
 ('hotel-hospitality','front-office','Front Office',30,'Front Desk Agent|Hotel Receptionist|Reservation Agent|Night Auditor'),
 ('hotel-hospitality','banquets','Banquets',40,'Banquet Server|Banquet Supervisor|Banquet Setup Worker'),
 ('hotel-hospitality','hotel-facilities','Hotel Facilities',50,'Pool Attendant|Lifeguard|Hotel Maintenance Technician'),
 ('catering','production-kitchen','Production Kitchen',10,'Catering Chef|Bulk Cook|Catering Cook|Catering Kitchen Helper|Food Packing Worker'),
 ('catering','catering-service','Catering Service',20,'Catering Waiter|Catering Supervisor|Catering Driver|Catering Steward'),
 ('cleaning','commercial-cleaning','Commercial Cleaning',10,'General Cleaner|Office Cleaner|Building Cleaner|Mall Cleaner|School Cleaner|Hospital Cleaner'),
 ('cleaning','specialist-cleaning','Specialist Cleaning',20,'Deep Cleaning Worker|Kitchen Cleaner|Washroom Cleaner|Window Cleaner|Glass Cleaner|Facade Cleaner|Industrial Cleaner'),
 ('cleaning','cleaning-operations','Cleaning Operations',30,'Cleaning Supervisor|Cleaning Team Leader|Janitor|Waste Collector|Pest Control Technician'),
 ('housekeeping','residential-housekeeping','Residential Housekeeping',10,'Housekeeper|Housekeeping Supervisor|Laundry Attendant|Linen Attendant'),
 ('facility-management','fm-operations','FM Operations',10,'FM Technician|Facility Technician|FM Supervisor|Building Maintenance Worker'),
 ('facility-management','fm-support','FM Support',20,'Multi Technician|Handyman|BMS Operator|Helpdesk Coordinator'),
 ('construction-civil','masonry','Masonry',10,'Mason|Block Mason|Tile Mason|Marble Mason|Plaster Mason|Interlock Mason|Waterproofing Worker'),
 ('construction-civil','civil-trades','Civil Trades',20,'Scaffolder|Rigger|Construction Helper|General Labourer|Foreman|Site Supervisor|Civil Supervisor|Survey Helper'),
 ('construction-civil','concrete-formwork','Concrete & Formwork',30,'Shuttering Carpenter|Steel Fixer|Rebar Worker|Concrete Worker|Formwork Foreman'),
 ('mep','electrical','Electrical',10,'Electrician|Electrical Technician|Industrial Electrician|Building Electrician|Cable Technician|Cable Jointer|Electrical Helper|Low Voltage Technician'),
 ('mep','hvac','HVAC & Refrigeration',20,'AC Technician|HVAC Technician|Refrigeration Technician|Chiller Technician|Ductman|Duct Fabricator|HVAC Helper|AC Installer'),
 ('mep','plumbing','Plumbing',30,'Plumber|Pipe Fitter|Plumbing Technician|Plumbing Helper|Sanitary Technician|Drainage Technician'),
 ('mep','fire-systems','Fire & Life Safety',40,'Fire Alarm Technician|Fire Fighting Technician|Sprinkler Technician|Fire Pipe Fitter'),
 ('carpentry-joinery','woodwork','Woodwork & Joinery',10,'Carpenter|Furniture Carpenter|Joinery Carpenter|Cabinet Maker|Wood Polisher|Carpenter Helper'),
 ('carpentry-joinery','gypsum-ceiling','Gypsum & Ceiling',20,'Gypsum Carpenter|False Ceiling Installer|Partition Installer|Ceiling Fixer'),
 ('painting','surface-finishing','Surface Finishing',10,'Painter|Spray Painter|Wall Painter|Decorative Painter|Painter Helper'),
 ('welding-fabrication','welding','Welding',10,'Welder|Arc Welder|MIG Welder|TIG Welder|Gas Welder|Welding Helper'),
 ('welding-fabrication','fabrication','Fabrication',20,'Aluminium Fabricator|Steel Fabricator|Metal Fabricator|Sheet Metal Worker|Fabrication Foreman'),
 ('steel-structural','structural-steel','Structural Steel',10,'Structural Steel Fabricator|Structural Steel Erector|Steel Fixer|Bolt Up Worker|Steel Supervisor'),
 ('manufacturing-factory','production','Production',10,'Production Worker|Factory Helper|Assembly Worker|Food Production Worker|Production Supervisor'),
 ('manufacturing-factory','machine-operations','Machine Operations',20,'Machine Operator|Machine Helper|CNC Operator|Lathe Operator|Milling Machine Operator|Press Machine Operator|Plastic Machine Operator|Printing Machine Operator'),
 ('manufacturing-factory','quality-packaging','Quality & Packaging',30,'Packaging Worker|Packing Worker|Quality Inspector|Quality Checker|Factory Cleaner'),
 ('warehouse-logistics','warehouse-operations','Warehouse Operations',10,'Warehouse Helper|Picker|Packer|Picker Packer|Loader|Unloader|Storekeeper|Assistant Storekeeper|Inventory Assistant'),
 ('warehouse-logistics','warehouse-equipment','Warehouse Equipment',20,'Forklift Operator|Reach Truck Operator|Pallet Jack Operator'),
 ('warehouse-logistics','warehouse-control','Warehouse Control',30,'Warehouse Supervisor|Warehouse Team Leader|Dispatch Assistant|Receiving Assistant|Logistics Coordinator|Sorting Worker'),
 ('delivery-courier','last-mile','Last-mile Delivery',10,'Delivery Rider|Courier Rider|Bike Rider|Delivery Driver|Van Delivery Driver|Delivery Helper'),
 ('driving-transport','passenger-driving','Passenger Driving',10,'Light Vehicle Driver|Taxi Driver|Limousine Driver|Bus Driver|School Bus Driver|Heavy Bus Driver'),
 ('driving-transport','freight-driving','Freight Driving',20,'Heavy Vehicle Driver|Truck Driver|Trailer Driver|Pickup Driver|Van Driver'),
 ('driving-transport','heavy-equipment','Heavy Equipment',30,'Excavator Operator|JCB Operator|Crane Operator|Bobcat Operator|Loader Operator|Bulldozer Operator'),
 ('automotive-garage','mechanical','Mechanical Repair',10,'Auto Mechanic|Diesel Mechanic|Petrol Mechanic|Heavy Vehicle Mechanic|Bus Mechanic|Truck Mechanic'),
 ('automotive-garage','electrical-diagnostics','Electrical & Diagnostics',20,'Auto Electrician|Diagnostic Technician|Automotive AC Technician|Battery Technician'),
 ('automotive-garage','body-detailing','Body & Detailing',30,'Tyre Technician|Wheel Alignment Technician|Car Polisher|Car Detailer|Car Washer|Denter|Auto Painter|Body Shop Technician'),
 ('automotive-garage','workshop-support','Workshop Support',40,'Service Advisor|Workshop Supervisor|Spare Parts Salesperson|Spare Parts Picker'),
 ('retail','store-sales','Store Sales',10,'Sales Associate|Retail Salesperson|Cashier|Store Helper|Counter Staff|Promoter'),
 ('retail','store-operations','Store Operations',20,'Shelf Stocker|Merchandiser|Retail Supervisor|Store Supervisor|Store Manager'),
 ('supermarket','fresh-food','Fresh Food',10,'Butcher|Fish Cutter|Vegetable Cutter|Bakery Assistant|Meat Cutter'),
 ('supermarket','supermarket-operations','Supermarket Operations',20,'Trolley Attendant|Supermarket Cleaner|Packing Staff|Supermarket Delivery Staff'),
 ('sales-customer-service','field-sales','Field Sales',10,'Sales Executive|Sales Coordinator|Merchandising Promoter'),
 ('sales-customer-service','customer-service','Customer Service',20,'Customer Service Representative|Call Center Agent|Customer Service Assistant'),
 ('security','security-operations','Security Operations',10,'Security Guard|Security Officer|Security Supervisor|CCTV Operator|Loss Prevention Officer|Gatekeeper|Watchman|Bouncer'),
 ('salon-beauty','hair-grooming','Hair & Grooming',10,'Barber|Hair Stylist|Hairdresser|Salon Assistant'),
 ('salon-beauty',…279 tokens truncated…sistant'),
 ('office-administration','business-support','Business Support',20,'PRO Assistant|HR Assistant|Sales Coordinator|Customer Service Representative|Call Center Agent'),
 ('maintenance','building-maintenance','Building Maintenance',10,'Maintenance Technician|Electrical Maintenance Technician|Plumbing Maintenance Technician|HVAC Maintenance Technician|Building Maintenance Supervisor'),
 ('general-labour','general-support','General Support',10,'General Helper|Loading Worker|Packing Helper|Site Helper|Factory Helper|Kitchen Helper'),
 ('marine-oil-gas','marine-support','Marine Support',10,'Marine Electrician|Marine Mechanic|Roustabout|Offshore Helper|Marine Pipe Fitter'),
 ('events','event-support','Event Support',10,'Event Setup Worker|Stagehand|Event Cleaner|Usher|Ticketing Assistant'),
 ('domestic-services','home-services','Home Services',10,'Domestic Helper|Nanny|Personal Driver|Home Cook|Live-in Caregiver')
), inserted_categories as (
 insert into public.job_categories(industry_id,name,slug,sort_order)
 select i.id,c.name,c.slug,c.sort_order from category_seed c join public.industries i on i.slug=c.industry_slug
 on conflict (industry_id,slug) do update set name=excluded.name,sort_order=excluded.sort_order,active=true returning id,slug
)
insert into public.job_roles(category_id,name,slug,sort_order)
select jc.id, btrim(role), regexp_replace(public.kaam_normalize_catalog_text(role),' ','-','g'), ordinality
from category_seed c join public.industries i on i.slug=c.industry_slug join public.job_categories jc on jc.industry_id=i.id and jc.slug=c.slug
cross join lateral unnest(string_to_array(c.roles,'|')) with ordinality as r(role,ordinality)
on conflict (category_id,slug) do update set name=excluded.name,sort_order=excluded.sort_order,active=true;

-- Genuine competencies. These are deliberately independent from occupations.
with skill_seed(name) as (select unnest(string_to_array(
 'Dough preparation|Porotta preparation|Indian bread preparation|Tawa cooking|Tandoor operation|Grill cooking|BBQ preparation|Biryani preparation|Curry preparation|Knife handling|Food preparation|Food safety|Kitchen hygiene|High-volume kitchen experience|Recipe execution|Portion control|Bakery production|Pastry preparation|Cake decoration|Pizza preparation|Burger preparation|Sandwich preparation|Beverage preparation|Juice preparation|Tea preparation|Coffee brewing|Espresso extraction|Milk steaming|Table service|Food serving|Order taking|POS operation|Upselling|Guest greeting|Cash handling|Restaurant supervision|Dishwashing|Kitchen stewarding|Food packing|Banquet service|Room cleaning|Bed making|Linen handling|Laundry sorting|Ironing|Dry cleaning|Guest relations|Reservation handling|Front desk operation|Telephone etiquette|Pool safety|Lifeguarding|Catering setup|Bulk food production|Commercial cleaning|Deep cleaning|Floor cleaning|Glass cleaning|Facade cleaning|Washroom cleaning|Kitchen cleaning|Chemical handling|Cleaning machine operation|Waste handling|Pest control|Housekeeping inspection|Cleaning team supervision|Building maintenance|BMS monitoring|Preventive maintenance|Work order handling|Electrical wiring|Cable pulling|Conduit installation|DB installation|Electrical troubleshooting|Electrical drawing reading|Cable jointing|Low voltage systems|Split AC installation|Refrigerant charging|Compressor diagnosis|HVAC troubleshooting|Duct installation|Duct fabrication|Chiller maintenance|Refrigeration repair|Plumbing installation|Pipe fitting|Leak detection|Drainage installation|Sanitary fixture installation|Fire alarm installation|Firefighting systems|Sprinkler installation|Wood cutting|Furniture assembly|Joinery installation|Cabinet installation|Wood polishing|Gypsum installation|False ceiling installation|Partition installation|Surface preparation|Wall painting|Spray painting|Decorative painting|Welding|Arc welding|MIG welding|TIG welding|Gas welding|Metal fabrication|Aluminium fabrication|Steel fabrication|Sheet metal work|Structural steel erection|Rebar fixing|Concrete work|Formwork installation|Scaffolding|Rigging|Waterproofing|Site safety|Tool handling|Machine operation|CNC machining|Lathe operation|Milling operation|Press machine operation|Plastic processing|Printing operation|Assembly line work|Packaging|Quality inspection|Production planning|Inventory handling|Barcode scanning|Picking|Packing|Loading unloading|Stock counting|Forklift operation|Reach truck operation|Pallet handling|Dispatch coordination|Goods receiving|Route planning|Motorcycle riding|Defensive driving|Vehicle inspection|Heavy vehicle driving|Passenger transport|Load securing|Excavator operation|JCB operation|Crane operation|Bobcat operation|Engine repair|Diesel engine repair|Petrol engine repair|Brake repair|Vehicle diagnostics|Auto electrical troubleshooting|Automotive AC repair|Battery servicing|Tyre replacement|Wheel alignment|Car polishing|Vehicle detailing|Car washing|Auto dent repair|Auto painting|Spare parts identification|Retail selling|Shelf replenishment|Visual merchandising|Customer assistance|Fresh food handling|Meat cutting|Fish cleaning|Vegetable preparation|Trolley collection|Field sales|Lead generation|Complaint handling|Call handling|Access control|CCTV monitoring|Incident reporting|Loss prevention|Crowd management|Hair cutting|Hair coloring|Hair styling|Shaving|Facial treatment|Skin care|Nail care|Manicure|Pedicure|Massage therapy|Makeup application|Henna design|Salon booking|Garment washing|Garment pressing|Stain removal|Textile care|Irrigation|Plant care|Pruning|Landscaping|Pesticide handling|Greenhouse operations|Patient support|Elderly care|Mobility assistance|Basic hygiene care|Ward support|Medical appointment booking|Clinic reception|Dental chair assistance|Pharmacy stock handling|Office filing|Data entry|Document control|Office administration|Mail handling|Pantry service|Government liaison|HR coordination|General maintenance|Handyman repairs|Painting touch-up|Labour support|Material handling|Event setup|Stage setup|Ticket scanning|Child care|Home cleaning|Home cooking|Personal assistance', '|')))
insert into public.competency_skills(name,slug,sort_order)
select name,regexp_replace(public.kaam_normalize_catalog_text(name),' ','-','g'),row_number() over ()
from (
  select name from skill_seed
  union all
  select unnest(string_to_array('Hygiene procedures|Tile installation|Bolt tightening|Marine electrical work|Marine mechanical repair|Event cleaning|Sales coordination|Customer service|Food allergen awareness|Kitchen inventory control|Menu knowledge|Bread baking|Dough kneading|Charcoal grilling|Shawarma carving|Tandoor bread baking|Rice cooking|Sauce preparation|Cold kitchen preparation|Dessert plating|Coffee machine cleaning|Cashier reconciliation|Restaurant reservations|Buffet setup|Table clearing|Hotel room inspection|Lost and found handling|Guest complaint resolution|Uniform care|Commercial laundry operation|Carpet cleaning|Upholstery cleaning|High pressure washing|Steam cleaning|Facade access safety|Pest identification|Building inspection|Generator maintenance|Pump maintenance|Electrical panel maintenance|Air balancing|HVAC duct cleaning|Copper pipe brazing|Pipe threading|Pressure testing|Fire pump maintenance|Fire extinguisher inspection|Cable tray installation|Wood sanding|Laminate installation|Tile grouting|Grout mixing|Plaster application|Interlock laying|Scaffold inspection|Lifting signal communication|Welding inspection|Metal cutting|Grinding|Drilling|Measurement reading|Blueprint interpretation','|'))
) seeded
on conflict (slug) do update set name=excluded.name,active=true;

-- Every role receives the most relevant 4-8 competencies from its category. This
-- starter mapping is intentionally conservative and can be curated by admins later.
with category_skill_seed(category_slug, skills) as (values
 ('kitchen','Food preparation|Food safety|Kitchen hygiene|Knife handling|Recipe execution|Portion control'),('bakery','Bakery production|Pastry preparation|Food safety|Kitchen hygiene|Recipe execution'),('quick-service','Food preparation|Food safety|Kitchen hygiene|POS operation|High-volume kitchen experience'),('beverage','Beverage preparation|Coffee brewing|Juice preparation|Tea preparation|Customer service'),('front-of-house','Table service|Order taking|POS operation|Upselling|Customer assistance|Cash handling'),('stewarding','Dishwashing|Kitchen stewarding|Kitchen hygiene|Waste handling|Chemical handling'),('restaurant-delivery','Route planning|Food packing|Motorcycle riding|Defensive driving|Customer service'),('hotel-housekeeping','Room cleaning|Bed making|Linen handling|Housekeeping inspection|Cleaning machine operation'),('guest-services','Guest relations|Guest greeting|Telephone etiquette|Customer assistance'),('front-office','Front desk operation|Reservation handling|Telephone etiquette|Guest relations|Cash handling'),('banquets','Banquet service|Food serving|Event setup|Table service'),('hotel-facilities','Pool safety|Lifeguarding|Building maintenance|Preventive maintenance'),('production-kitchen','Bulk food production|Food packing|Food safety|Kitchen hygiene|Portion control'),('catering-service','Catering setup|Banquet service|Food serving|Route planning'),('commercial-cleaning','Commercial cleaning|Floor cleaning|Chemical handling|Waste handling|Hygiene procedures'),('specialist-cleaning','Deep cleaning|Glass cleaning|Chemical handling|Cleaning machine operation|Site safety'),('cleaning-operations','Cleaning team supervision|Housekeeping inspection|Waste handling|Pest control'),('residential-housekeeping','Home cleaning|Linen handling|Laundry sorting|Ironing|Housekeeping inspection'),('fm-operations','Building maintenance|Preventive maintenance|Work order handling|BMS monitoring'),('fm-support','General maintenance|Handyman repairs|Work order handling|Tool handling'),('masonry','Concrete work|Tile installation|Surface preparation|Waterproofing|Tool handling|Site safety'),('civil-trades','Scaffolding|Rigging|Site safety|Material handling|Tool handling'),('concrete-formwork','Formwork installation|Rebar fixing|Concrete work|Site safety|Tool handling'),('electrical','Electrical wiring|Cable pulling|Conduit installation|DB installation|Electrical troubleshooting|Electrical drawing reading'),('hvac','Split AC installation|Refrigerant charging|HVAC troubleshooting|Duct installation|Chiller maintenance|Preventive maintenance'),('plumbing','Plumbing installation|Pipe fitting|Leak detection|Drainage installation|Sanitary fixture installation'),('fire-systems','Fire alarm installation|Firefighting systems|Sprinkler installation|Electrical drawing reading|Site safety'),('woodwork','Wood cutting|Furniture assembly|Joinery installation|Cabinet installation|Wood polishing'),('gypsum-ceiling','Gypsum installation|False ceiling installation|Partition installation|Tool handling|Site safety'),('surface-finishing','Surface preparation|Wall painting|Spray painting|Decorative painting|Site safety'),('welding','Welding|Arc welding|MIG welding|TIG welding|Gas welding|Site safety'),('fabrication','Metal fabrication|Aluminium fabrication|Steel fabrication|Sheet metal work|Welding'),('structural-steel','Structural steel erection|Steel fabrication|Rigging|Bolt tightening|Site safety'),('production','Assembly line work|Production planning|Quality inspection|Site safety|Tool handling'),('machine-operations','Machine operation|CNC machining|Lathe operation|Milling operation|Quality inspection|Site safety'),('quality-packaging','Packaging|Quality inspection|Stock counting|Cleaning machine operation'),('warehouse-operations','Picking|Packing|Loading unloading|Inventory handling|Barcode scanning|Stock counting'),('warehouse-equipment','Forklift operation|Reach truck operation|Pallet handling|Site safety|Vehicle inspection'),('warehouse-control','Dispatch coordination|Goods receiving|Inventory handling|Stock counting|Route planning'),('last-mile','Route planning|Motorcycle riding|Defensive driving|Food packing|Customer service'),('passenger-driving','Defensive driving|Passenger transport|Vehicle inspection|Route planning'),('freight-driving','Heavy vehicle driving|Load securing|Vehicle inspection|Route planning|Defensive driving'),('heavy-equipment','Excavator operation|JCB operation|Crane operation|Bobcat operation|Vehicle inspection|Site safety'),('mechanical','Engine repair|Diesel engine repair|Petrol engine repair|Brake repair|Vehicle diagnostics'),('electrical-diagnostics','Auto electrical troubleshooting|Vehicle diagnostics|Automotive AC repair|Battery servicing'),('body-detailing','Tyre replacement|Wheel alignment|Car polishing|Vehicle detailing|Car washing|Auto painting'),('workshop-support','Spare parts identification|Customer service|Vehicle inspection|Inventory handling'),('store-sales','Retail selling|Customer assistance|POS operation|Cash handling|Upselling'),('store-operations','Shelf replenishment|Visual merchandising|Inventory handling|Stock counting|Customer assistance'),('fresh-food','Fresh food handling|Meat cutting|Fish cleaning|Vegetable preparation|Food safety'),('supermarket-operations','Trolley collection|Commercial cleaning|Packing|Customer assistance|Route planning'),('field-sales','Field sales|Lead generation|Customer service|Upselling|Complaint handling'),('customer-service','Call handling|Complaint handling|Customer assistance|Telephone etiquette|Data entry'),('security-operations','Access control|CCTV monitoring|Incident reporting|Loss prevention|Crowd management'),('hair-grooming','Hair cutting|Hair coloring|Hair styling|Shaving|Salon booking'),('beauty-wellness','Facial treatment|Skin care|Nail care|Massage therapy|Makeup application|Henna design'),('laundry-operations','Garment washing|Garment pressing|Stain removal|Textile care|Laundry sorting'),('farm-operations','Irrigation|Plant care|Pesticide handling|Greenhouse operations|Site safety'),('landscape-operations','Landscaping|Plant care|Pruning|Irrigation|Tool handling'),('patient-support','Patient support|Elderly care|Mobility assistance|Basic hygiene care|Ward support'),('clinic-support','Clinic reception|Medical appointment booking|Dental chair assistance|Pharmacy stock handling|Hygiene procedures'),('office-support','Office filing|Data entry|Document control|Office administration|Mail handling|Pantry service'),('business-support','Government liaison|HR coordination|Sales coordination|Customer service|Call handling'),('building-maintenance','General maintenance|Preventive maintenance|Handyman repairs|Painting touch-up|Work order handling'),('general-support','Labour support|Material handling|Tool handling|Site safety|Packing'),('marine-support','Marine electrical work|Marine mechanical repair|Rigging|Pipe fitting|Site safety'),('event-support','Event setup|Stage setup|Ticket scanning|Crowd management|Event cleaning'),('home-services','Home cleaning|Home cooking|Child care|Personal assistance|Elderly care')
)
insert into public.job_role_skills(job_role_id,competency_skill_id,relevance,is_core,sort_order)
select r.id,s.id,case when x.ordinality <= 4 then 90 else 70 end,x.ordinality <= 4,x.ordinality
from category_skill_seed css join public.job_categories c on c.slug=css.category_slug join public.job_roles r on r.category_id=c.id
cross join lateral unnest(string_to_array(css.skills,'|')) with ordinality x(name,ordinality)
join public.competency_skills s on s.slug=regexp_replace(public.kaam_normalize_catalog_text(x.name),' ','-','g')
on conflict (job_role_id,competency_skill_id) do update set relevance=excluded.relevance,is_core=excluded.is_core,sort_order=excluded.sort_order;

-- Equivalent spelling/transliteration aliases only; related roles stay separate.
with alias_seed(role_slug, alias) as (values
 ('porotta-maker','Parotta Maker'),('porotta-maker','Paratha Maker'),('porotta-maker','Kerala Porotta Maker'),('porotta-maker','Porotta Master'),('porotta-maker','Parotta Master'),
 ('waiter-server','Waiter'),('waiter-server','Waitress'),('waiter-server','Server'),
 ('hvac-technician','Air Conditioning Technician'),('hvac-technician','Aircon Technician'),('hvac-technician','A C Technician'),
 ('ac-technician','AC Tech'),('tile-mason','Tile Fixer'),('auto-mechanic','Car Mechanic'),('bike-rider','Motorbike Rider'),('picker-packer','Picker Packer'),('general-cleaner','Cleaner'),('sales-associate','Salesman'),('sales-associate','Saleswoman'),('barber','Gents Barber'),('hair-stylist','Hairdresser'),('office-boy','Tea Boy'),('pantry-assistant','Pantry Boy')
)
insert into public.job_role_aliases(job_role_id,alias)
select r.id,a.alias from alias_seed a join public.job_roles r on r.slug=a.role_slug
on conflict (normalized_alias) do nothing;

-- Exact, reviewable mappings from the legacy occupation-like skills table.
insert into public.legacy_role_mappings(source_type,source_id,source_value,canonical_job_role_id,mapping_confidence,mapping_method,reviewed)
select 'legacy_skills',s.id,s.name,r.id,1.000,'exact_name',false
from public.skills s join public.job_roles r on public.kaam_normalize_catalog_text(r.name)=public.kaam_normalize_catalog_text(s.name)
on conflict (source_type,source_id) do update set canonical_job_role_id=excluded.canonical_job_role_id,mapping_confidence=excluded.mapping_confidence,mapping_method=excluded.mapping_method;

insert into public.legacy_role_mappings(source_type,source_id,source_value,canonical_job_role_id,mapping_confidence,mapping_method,reviewed)
select 'legacy_skills',s.id,s.name,a.job_role_id,0.950,'exact_alias',false
from public.skills s join public.job_role_aliases a on a.normalized_alias=public.kaam_normalize_catalog_text(s.name)
on conflict (source_type,source_id) do nothing;

create or replace view public.legacy_role_mapping_coverage with (security_invoker = true) as
select 'legacy_skills'::text as source_type,
  count(*) as total_records,
  count(m.id) filter (where m.canonical_job_role_id is not null) as mapped_records,
  count(*) filter (where m.id is null or m.canonical_job_role_id is null) as unmapped_records,
  coalesce(round(count(m.id) filter (where m.canonical_job_role_id is not null)::numeric / nullif(count(*),0),3),0) as mapping_coverage
from public.skills s left join public.legacy_role_mappings m on m.source_type='legacy_skills' and m.source_id=s.id;
grant select on public.legacy_role_mapping_coverage to authenticated;

create or replace function public.search_job_roles(search_text text, result_limit integer default 20)
returns table(job_role_id uuid, role_name text, role_slug text, category_name text, category_slug text, industry_name text, industry_slug text, matched_alias text, relevance real)
language sql stable security invoker set search_path = public
as $$
  with q as (select public.kaam_normalize_catalog_text(coalesce(search_text,'')) as term), candidates as (
    select r.id,r.name,r.slug,c.name category_name,c.slug category_slug,i.name industry_name,i.slug industry_slug,null::text matched_alias,
      greatest(similarity(public.kaam_normalize_catalog_text(r.name),q.term),case when public.kaam_normalize_catalog_text(r.name) like q.term || '%' then 1 else 0 end)::real relevance
    from public.job_roles r join public.job_categories c on c.id=r.category_id join public.industries i on i.id=c.industry_id cross join q
    where r.active and c.active and i.active and q.term <> '' and (public.kaam_normalize_catalog_text(r.name) % q.term or public.kaam_normalize_catalog_text(r.name) like '%' || q.term || '%')
    union all
    select r.id,r.name,r.slug,c.name,c.slug,i.name,i.slug,a.alias,
      greatest(similarity(a.normalized_alias,q.term),case when a.normalized_alias like q.term || '%' then 1 else 0 end)::real
    from public.job_role_aliases a join public.job_roles r on r.id=a.job_role_id join public.job_categories c on c.id=r.category_id join public.industries i on i.id=c.industry_id cross join q
    where r.active and c.active and i.active and q.term <> '' and (a.normalized_alias % q.term or a.normalized_alias like '%' || q.term || '%')
  ), ranked as (select *,row_number() over(partition by id order by relevance desc, matched_alias nulls last) rn from candidates)
  select id,name,slug,category_name,category_slug,industry_name,industry_slug,matched_alias,relevance from ranked where rn=1 order by relevance desc,name limit greatest(1,least(coalesce(result_limit,20),50));
$$;
revoke all on function public.search_job_roles(text,integer) from public;
grant execute on function public.search_job_roles(text,integer) to authenticated;

-- Guard against accidentally replacing this with a tiny taxonomy in later edits.
do $$
begin
  if (select count(*) from public.industries where active) < 20 then raise exception 'Phase 1 taxonomy needs at least 20 industries'; end if;
  if (select count(*) from public.job_categories where active) < 60 then raise exception 'Phase 1 taxonomy needs at least 60 categories'; end if;
  if (select count(*) from public.job_roles where active) < 250 then raise exception 'Phase 1 taxonomy needs at least 250 roles'; end if;
  if (select count(*) from public.competency_skills where active) < 250 then raise exception 'Phase 1 taxonomy needs at least 250 competency skills'; end if;
end $$;

notify pgrst, 'reload schema';
commit;


