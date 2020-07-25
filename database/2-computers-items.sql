create table computer (
  id int primary key,
  ty text not null, --"plain", "turtle", "pocket", or "neural"
  is_golden boolean not null
);

create table chest (
  computer int not null references computer(id),
  name text not null,
  ty text not null, --"in", "out", "storage"
  slots int not null,
  primary key (computer, name)
);

create table item (
  id serialint not null primary key,
  name text not null, --"minecraft:whatever"
  damage int not null,
  maxDamage int not null,
  rawName text not null,
  nbtHash text,
  fullMeta jsonb not null
);

create table stack (
  chest_computer int not null,
  chest_name text not null,
  slot tinyint not null,
  item_id int not null references item(id),
  count int not null,
  foreign key (chest_computer, chest_name) references chest(computer, name),
  primary key (chest_computer, chest_name, slot)
);

create index on stack(item_id);
create index on item(name,nbtHash);
create index on chest(ty);
