#
# FILE:     postReplies.pl
# PURPOSE:  Populate the posts_replies table
#
# course, year, term, forum_id, discussion_id, 
# - where the post/reply sites
# post_id, userid, role, post_timecreated, 
# - details about the post itself
# parent_id, userid, role, parent_timecreated
# - details about what (and if) this is a reply
#
# -- ?? is role needed
#   
#   

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;

use webfuse::lib::BAM::3100::MoodleUsers;
use Data::Dumper;

my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

require "$WEBFUSE_HOME/lib/QILTers/library.pl";

my $POSTS_REPLIES_DEFAULTS = {
    TABLE => "posts_replies",
    FIELDS => "course,year,term,forumid,discussionid," .
              "postid,postAuthorid,postAuthorRole,postTimeCreated," .
              "parentid,parentAuthorid,parentAuthorRole,parentTimeCreated",
    CONDITIONS => "forumid={forumid}"  #-- for initial deleting of data
};

my @OFFERINGS = (  qw/ EDC3100_2015_2 EDC3100_2015_1 
    EDS4250_2015_1 EDS4250_2015_2 EDC1400_2015_1
EDC1400_2015_2 EDS2401_2015_2 EDS2401_2015_1 EDX3160_2015_2 EDX3270_2015_1
EDX3270_2015_2 EDC4000_2015_2 EDC4000_2015_1 EDP4130_2015_1
/ );

my $ids = getCourseDetails( \@OFFERINGS );

if ( $ids->NumberOfRows == 0 ) {
    die "Didn't find any matching offerings\n";
}

#-- cycle through the offerings 
foreach my $offering ( @{$ids->{DATA}} ) {
    #-- get the course/term/year information
    my @offering = split /_/, $offering->{shortname};
    my $course = $offering[0];  my $year = $offering[1]; 
    my $term = $offering[2];

    #-- array of data to insert into posts_replies
    my @posts;

    #-- get user role information 
    my $roles = getAllCourseRoles( course => $course, year => $year,
                                   term => $term );
#print Dumper( \$roles );
#die;

    my $forums = getAllForums( $offering->{id} );


#print Dumper( $forums);
#die;

    #-- loop through all forums
    #    { name =>, id =>, type => }
    foreach my $forum ( @{$forums->{DATA}} ){
        my $discussions = getAllForumsDiscussions( $offering->{id}, 
                                $forum->{id} );
#print Dumper( $discussions );
#die;
        #-- loop through all discussions
        # { id =>, firstpost }
        foreach my $discussion ( @{$discussions->{DATA}} ) {
            my $posts = getAllDiscussionPosts( $discussion->{id} );
#print Dumper( $posts );
#die;
            # - may need to get hash in order to access parent information
            #   and populate @posts as required
            my %posts = map { ( $_->{id} => $_ ) } @{$posts->{DATA}};
#print Dumper( \%posts );
#die;
            #-- loop through all posts in discussion
            #   { created => parent => userid => id => modified => }
            foreach my $post ( @{$posts->{DATA}} ) {
                #--
                my $newPost = {
                    course => $course, year => $year, term => $term,
                    forumid => $forum->{id},
                    discussionid => $discussion->{id},
                    postid => $post->{id},
                    postAuthorid => $post->{userid},
                    postAuthorRole => $roles->{$post->{userid}},
                    postTimeCreated => $post->{created} ,
                    parentId => "NULL", parentAuthorid => "NULL",
                    parentAuthorRole => "NULL",
                    parentTimeCreated => "NULL"
                };

                if ( $post->{parent} != 0 ) {
                    my $parent = $posts{$post->{parent}};

                    $newPost->{parentId} = $post->{parent};
                    $newPost->{parentAuthorid} = $parent->{userid},
                    $newPost->{parentAuthorRole} = $roles->{$parent->{userid}},
                    $newPost->{parentTimeCreated} = $parent->{created};
                }

                push @posts, $newPost;
            }
        }
    }

#print Dumper( \@posts );
#die;
    #-- insert the new data into posts_replies
    insertPosts( \@posts );
#die;
}


#----------------------------------------------------
# insertPosts( \@data )
# - given some data, stick it into posts_replies - remove any matching data
#   first

sub insertPosts( $ ) {
    my $posts = shift;

    my $count = @$posts;
    if ( $count == 0 ) {
        return;
    }

    my $forum = $posts->[0]->{forumid};
    my $tablePosts = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $POSTS_REPLIES_DEFAULTS,
                KEYS => { forumid => $forum } );

#print Dumper( $tablePosts->{DATA} );
#die;
    #-- delete any existing data from mdl_users_extra
    if ( $tablePosts->NumberOfRows() > 0 ) {
        $tablePosts->delete();
        $tablePosts->{DATA} = [];
    }

    #-- insert the new data
    $tablePosts->{DATA} = $posts;
    $tablePosts->{DEBUG} = 0;

    $tablePosts->{CONDITIONS} = "";

    $tablePosts->Insert();

    if ( $tablePosts->Errors() ) {
        $tablePosts->DumpErrors();
        die;
    }
}
