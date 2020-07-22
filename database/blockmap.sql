create table blocks (
  num smallserial primary key,
  idname text not null,
  blockMeta jsonb not null
);

create table grid (
  x smallint not null,
  y smallint not null,
  z smallint not null,
  block smallint not null references blocks(num),
  primary key (x, y, z)
);

create table meta (
  x smallint not null,
  y smallint not null,
  z smallint not null,
  nbtLike jsonb not null,
  foreign key (x, y, z) references grid
);
