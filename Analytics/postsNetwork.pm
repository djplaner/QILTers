#
# FILE:		QILTers::Analytics::postsNetwork.pm
# PURPOSE:	Model to map postsNetwork (and various filters) for a given course
#
# TO DO:	
#

package QILTers::Analytics::postsNetwork;

$VERSION = '0.5';

use strict;

use Data::Dumper;

use webfuse::lib::NewModel;
use webfuse::lib::QILTers::Analytics::clickGrades;

@QILTers::Analytics::postsNetwork::ISA = ( "QILTers::Analytics::clickGrades" );

#--------------------
# Globals

use webfuse::lib::WebfuseConfig;
my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

# CONDITIONS is constructed in handle_params based on parameters
# passed in

my $POSTS_REPLIES_DEFAULTS = {
    TABLE => "posts_replies",
    FIELDS => "course,year,term,forumid,discussionid," .
              "postid,postAuthorid,postAuthorRole,postTimeCreated," .
              "parentid,parentAuthorid,parentAuthorRole,parentTimeCreated",
    CONDITIONS => "course={course} and term={term} and year={year}"
};

my @REQUIRED_PARAMETERS = ( qw/ OFFERING course term year / );


#-------------------------------------------------------------
# new(  )

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    
    my %args = @_;

    $args{q_type} = "POSTS NETWORK";
    bless( $self, $class );

    $self = $self->SUPER::new( %args, DEFAULTS => $POSTS_REPLIES_DEFAULTS,
                               REQUIRED_PARAMETERS => \@REQUIRED_PARAMETERS  );

    $self->{CLICKS_GRADES} = QILTers::Analytics::clickGrades->new(
                                OFFERING => $args{OFFERING} );

    #-- generate the network model for all participants
    $self->{NETWORK_ALL} = $self->generateNetworkModel( $self->{DATA} );
    return $self;
}

#-------------------------------------------------------------
# generateNetworkModel( $subset )
# - take the data of array of hashes - perhaps a subset
# - return a hash with two entries
#   NODES
#   - id - unique id for each user
#   - role - either "student" or "teacher" 
#   - userid - the userid
#   EDGES
#    - id - new unique id - combo of two nodes connected
#    - source - source node id
#    - target - target node id
#    - weight - integer representing # of replies

sub generateNetworkModel($) {
    my $self = shift;
    my $posts = shift;

    my @role = ( qw/ student teacher / );
    my %array; my @nodes;  my @edges;

    #-- nodes will be all entries from
    my $count = 1;
    foreach my $user ( @{$self->{CLICKS_GRADES}->{DATA}} ) { 
        my $node = {
            id => $count, 
            role => $role[$user->{roleid}],
            userid => $user->{userid}
        };
        $count++;
        push @nodes, $node;
    }

    #-- create a hash connecting userid to an entry in @nodes
    # - used in edges
    my %userNodeHash = map { ( $_->{userid} => $_ ) } @nodes;
#print Dumper( \%userNodeHash );
#die;

    #-- create edges
    # - loop through all entries in posts replies
    # - if parent is defined the create an edge
    # - source is current post, target is parent
#print Dumper( $self->{DATA} );
#die;
    foreach my $post ( @{$self->{DATA}} ) {
        if ( $post->{parentid} ne "" ) {
            #-- increase the weight of edge between user and parent
            $userNodeHash{$post->{postauthorid}}->{REPLIES}->{$post->{parentauthorid}}->{WEIGHT}++;
        }
    }
#print Dumper( \%userNodeHash );
#die;
    #-- transform usernodehash data into 
#   EDGES - array of hashes
#    - id - new unique id - combo of two nodes connected
#    - source - source node id
#    - target - target node id

    #-- loop through each  NODE (user)
    foreach my $node ( @nodes ) {
        #-- loop through each REPLIES they have made
        # - $reply here is a userid they have replied to (target)
        foreach my $reply ( keys %{$node->{REPLIES}} ){
            my $source = $node->{id};
            my $target = $userNodeHash{$reply}->{id};
            if ( exists $userNodeHash{$reply}->{id} ) {
                my $edgeId = $source . "_" . $target;
                my $entry = {
                            id => $edgeId,
                            source => $source,
                            target => $target,
                            weight => $node->{REPLIES}->{$reply}->{WEIGHT}
                };
                push @edges, $entry;
            } else {
            #    print Dumper( $node );
            #    print Dumper( $node->{REPLIES}->{$reply} );
            #    die;
            }
        }
    }
#print Dumper( \@edges );
#die;
    
    $array{NODES} = \@nodes;
    $array{EDGES} = \@edges;
    return \%array;
}

1;


