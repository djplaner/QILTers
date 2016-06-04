create table mdl_user_extras (
  id bigint NOT NULL,
  course character varying(10),
  term smallint,
  year smallint,
  mark decimal,
  grade character varying(3),
  gpa decimal,
  program character varying(50),
  plan character varying(50),
  birthdate date,
  mode character varying(20),
  postal_code smallint,
  completed_units smallint,
  transferred_units smallint,
  acad_load character(1),
  UNIQUE ( id, course, term, year )
)


