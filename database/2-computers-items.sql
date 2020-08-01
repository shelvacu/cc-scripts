create table computer (
  id int primary key,
  ty text not null, --"plain", "turtle", "pocket", or "neural"
  is_golden boolean not null
);

create table chest (
  computer int not null references computer(id),
  name text not null,
  ty text not null, --"in", "out", "storage", "unknown"
  slots int not null,
  primary key (computer, name)
);

create table item (
  id serial not null primary key,
  name text not null, --"minecraft:whatever"
  damage int not null,
  maxDamage int not null,
  rawName text not null,
  -- goddammit postgres https://stackoverflow.com/questions/23449207/postgres-unique-constraint-not-enforcing-uniqueness
  -- if no hash is present, set to empty string
  nbtHash text not null,
  fullMeta jsonb not null
);

create table stack (
  chest_computer int not null,
  chest_name text not null,
  slot smallint not null,
  item_id int references item(id),
  count int not null,
  foreign key (chest_computer, chest_name) references chest(computer, name),
  primary key (chest_computer, chest_name, slot)
);

create index on stack(item_id);
create unique index item_fungible on item(name,damage,nbtHash);
create index on chest(ty);
--create unique index item_fungible_nonbt on item(name,damage) where nbtHash is null;
--create unique index item_fungible_nbt on item(name,damage,nbtHash) where nbtHash is not null;
