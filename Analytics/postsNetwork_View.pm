#
# FILE:		postsNetwork_View.pm
# PURPOSE:	View class for QILTers::Analytics::dhits
#                               
# TO DO:	
#

package QILTers::Analytics::postsNetwork_View;

$VERSION = '0.5';

use strict;
use Carp;

use HTML::Template;
use Data::Dumper;
use webfuse::lib::View;

@QILTers::Analytics::postsNetwork_View::ISA = ( qw/ View / );

use webfuse::lib::WebfuseConfig;
my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;

#-------------------------------------------------------------
# new( TYPE => $type, VIEW => $view_name, MODEL =>$model, FAMILY =>
#         ACCOUNT => $account, DIRECTORY => dir, FILE => file )
# - normally will get the HTML file
#           DIRECTORY/TYPE/VIEW.FAMILY
#   and replace {VARIABLE} with the contents of the model
# - this action can/might be modified based on the ACCOUNT if
#   passed THIS IS NOT IMPLEMENTED yet
# - this can be over ridden by specifying a direct FILE

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{ERRORS} = [];
  my %args = @_;

  bless( $self, $class );

  $self->{MODEL} = $args{MODEL} || undef;

  $self->{FAMILY} = $args{FAMILY} || "default";
  $self->{VIEW} = $args{VIEW} || "postsNetwork";
  $self->{TYPE} = $args{TYPE} || "";
  $self->{TYPE} =~ s/^(.*)\/$//;
  $self->{DIRECTORY} = $args{DIRECTORY} || "$WEBFUSE_HOME/lib/QILTers/Analytics/Views";
  $self->{DIRECTORY} =~ s/^(.*)\/$/$1/;
  $self->{FULL_PAGE} = 1;
  $self->{FULL_PAGE} = $args{FULL_PAGE} if ( exists $args{FULL_PAGE} );
  $self->{QUERY} = $args{QUERY} || undef;

  $self->{TEMPLATE} = $args{TEMPLATE} || "template.default";

  $self->{STUDENT} = $args{STUDENT} || undef;

  $self->{FILE} = $args{FILE} || "";

  return $self;
}

#---------------------------------------------------
# Display( SUBSET =>  COURSES => COURSE => OFFERING =>
#       VALUES --> used for templates
#       CLICKS --> clickGrade object
# - COURSES is the array of all we're doing
# - SUBSET COURSE and OFFERING are the specific one we're working on now
#
#

sub Display {
    my $self = shift;
    my %args = @_;

    #-- if we're doing content / forum clicks, we need clickGrades
    $self->{MODEL}->getClickGrades();

    $self->{VALUES} = \%args;

#print "**** VALUES \n";
#print Dumper( $self->{VALUES} );
#die;
    my $string;

    return $self->DisplayError() 
        if ( ! defined $self->{MODEL} || $self->{MODEL}->Errors );

    if ( ! $self->GetHTMLTemplate( 
                 "$self->{DIRECTORY}/$self->{VIEW}.$self->{FAMILY}",
                    die_on_bad_params => 0 ) ) {
        print $self->DumpErrors();
        die; 
    }

    #-- point to the right subset of data
    #   - for both dhits and clicks
print "Getting $self->{VALUES}->{SUBSET}\n";

    my $count = 1; #**** will need to be changed
    if ( $count != 0 ) {
        $self->plotly();
    }

    #-- now set up the rest of the page
 
    # Analytic name is title for the page
    # - course, offering, subset
    my $analyticName = "Reply network for " .
                        $self->{VALUES}->{COURSE} . " " .
                       $self->{VALUES}->{OFFERING} . " " .
                       $self->{VALUES}->{SUBSET};
    $self->{TEMPLATE}->param( ANALYTIC_NAME => $analyticName );

    #-- set up the nav menus at top of page
    # - entire site structure
    $self->{TEMPLATE}->param( COURSES => $self->{COURSES} )
        if  ( exists $self->{COURSES} );
    # - menu for the offering - basically the subsets
    my $subsets = $self->constructSubsetsView();
    $self->{TEMPLATE}->param( SUBSETS => $subsets );

    return $self->{TEMPLATE}->output();
}

#-----------------------------------------------------------------
# plotly()
# - DHITS_DATA is all rows for matching subset for DHITS
# - CLICKS_DATA is all rows for matching subset of ALL CLICKS
#
# - Need to create two arrays of hashes
#   - nodes 
#     - elements: 
#       - id - unique id ???? what ????
#       - role - either "student" or "teacher"
#     - edges:
#       - id - new unique id - combo of two nodes connected
#       - source - source node id
#       - target - target node id
#       - weight - integer representing # of replies
#
#  -- need an array of hashes from posts_replies
#   - Model will provide posts_replies for all posts/replies
#     - elements
#       - sourceid, targetid, weight
#  -- ids will be numbers - uniquly generated for each user
#
#   in MODEL->{NETWORK_ALL} by default
#   *** will need to work out  subsets

sub plotly( ) {
    my $self = shift;

    my $subset = $self->{MODEL}->{NETWORK_ALL};

    $self->{TEMPLATE}->param( nodes => $subset->{NODES},
                        edges => $subset->{EDGES} );
}

#-----------------------------------------------------------------
# constructSubsetsView
# - create an array of hashes
#       { LINK => NAME => }
#   for each of the subset views available for the current analytics
# - need to know
#   - what is the current analytic $self->{VIEWS}->{SUBSET}
#           $self->{VIEWS}->{COURSE} $self->{VIEWS}->{OFFERING}
#   - what are the possible subsets we're constructing
#       @{$self->{VIEWS}->{COURSES}->{$course}->{$offering}}
#   - what is the link for each of those subsets
#     - $PATH/COURSE/OFFERING/ANALYTIC/subset.html

sub constructSubsetsView() {
    my $self = shift;

    my $course = $self->{VALUES}->{COURSE};
    my $offering = $self->{VALUES}->{OFFERING};
    my $subset = $self->{VALUES}->{SUBSET};
    my $analytic = ref $self->{MODEL};
    $analytic =~ s/^.*:://;

#print Dumper( $self->{VALUES}->{COURSES}->{$course}->{$offering}->{$analytic} );
#die;

    my @subsets;

    foreach my $subset ( @{$self->{VALUES}->{COURSES}->{$course}->{$offering}->{$analytic}} ) {
        my $label = $subset;
        $label =~ s/_/ /g;
        my $element = { LABEL => $label  };

        my $link = $subset;
        $link = "index" if ( $link eq "all" ) ;
        $element->{LINK} = $self->{PATH} . 
                            "/$course/$offering/$analytic/$link.html";
        push @subsets, $element;
    }
    
    return \@subsets;
}


1;
