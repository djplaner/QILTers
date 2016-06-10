
q_type
- TOTAL CLICKS

roleid
- 0 - student
- 1 - teacher

create table qilt_quantities (
  id bigserial PRIMARY KEY,
  userid bigint NOT NULL,
  roleid bigint NOT NULL DEFAULT 0,
  course character varying(10),
  term smallint,
  year smallint,
  q_type character varying(50),
  quantity numeric,
  CONSTRAINT u_t_q UNIQUE( userid, course, term, year, q_type )
)


