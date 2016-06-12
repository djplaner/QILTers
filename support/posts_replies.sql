
# posts_replies
# - used for SNA and also LL LT and TT calculations

create table posts_replies (
  course character varying(10) NOT NULL,
  term smallint NOT NULL,
  year smallint NOT NULL,

  forumid bigint NOT NULL,
  discussionid bigint NOT NULL,
  postid bigint NOT NULL,
  postAuthorid bigint NOT NULL,
  postAuthorRole character varying(50),
  postTimeCreated bigint NOT NULL,

  parentid bigint,
  parentAuthorid bigint,
  parentAuthorRole character varying(50),
  parentTimeCreated bigint,

  CONSTRAINT course_postid UNIQUE( course, term, year, postid )
)


