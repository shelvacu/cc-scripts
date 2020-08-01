create table withdrawal (
  id serial not null primary key,
  item_id int not null references item(id),
  computer int not null,
  output_chest text not null,
  slot smallint,
  count smallint not null,
  finished boolean not null default false
);
