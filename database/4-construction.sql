-- Tables for recording crafting recipes and using them

-- This isn't a full representation of what can craft what; Some recipes are shapeless (as long as you have the right items they can be in any position), or can use theoretically infinitely many items (Plethora's "Frikin Laser Beam" needs anything enchanted with either fire aspect 1 or flame)
-- However, this should be good enough. It's perfectly capable of storing multiple recipes to create one thing.
-- This is only for recipes in a crafting table. Furnaces/Brewing stands are complicated, I'll add them later.
-- crafting table slots are numbered like so:
-- 1 2 3
-- 4 5 6
-- 7 8 9

-- why the out_*? some recipes (like cake) leave behind items in the crafting table. :gun: :upside_down:

create table crafting_recipe (
  id serial not null primary key,
  slot_1 int references item(id),
  slot_2 int references item(id),
  slot_3 int references item(id),
  slot_4 int references item(id),
  slot_5 int references item(id),
  slot_6 int references item(id),
  slot_7 int references item(id),
  slot_8 int references item(id),
  slot_9 int references item(id),
  result int not null references item(id),
  result_count int not null,
  out_1 int references item(id),
  out_2 int references item(id),
  out_3 int references item(id),
  out_4 int references item(id),
  out_5 int references item(id),
  out_6 int references item(id),
  out_7 int references item(id),
  out_8 int references item(id),
  out_9 int references item(id)
);

create table job_dep_graph (
  id serial not null primary key,
  parent int references job_dep_graph(id),
  finished boolean not null default false,
  item_id int references item(id), --not a structural requirement; used for display in UI
  quantity int, --also doesn't need to be correct
  name text --for display
);

-- A job's quantity must be at most one stack
-- This has the potential to create thousands of rows, but postgres would be pretty shit engine if it couldn't handle ThOuSaNdS of rows.
-- there can be "null" jobs which only serve to group other jobs. These have crafting_recipe_id and item_id null, and quantity set to 0.
create table job (
  id serial not null primary key,
  parent int references job_dep_graph(id),
  crafting_recipe_id int references crafting_recipe(id),
  item_id int references item(id),
  quantity int not null,
  finished boolean not null default false
);

create unique index on crafting_recipe(
  COALESCE(slot_1,-1),
  COALESCE(slot_2,-1),
  COALESCE(slot_3,-1),
  COALESCE(slot_4,-1),
  COALESCE(slot_5,-1),
  COALESCE(slot_6,-1),
  COALESCE(slot_7,-1),
  COALESCE(slot_8,-1),
  COALESCE(slot_9,-1)
);

create index on crafting_recipe(result);

create table emily_job (
  id serial primary key,
  recipe int not null references crafting_recipe(id),
  count int not null, --how many *times* to craft, not count of output
  count_finished int not null,
  prev int references emily_job(id)
);

create unique index on emily_job(parent);
