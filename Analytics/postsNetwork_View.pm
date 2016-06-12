#
# FILE:		dhits_View.pm
# PURPOSE:	View class for QILTers::Analytics::dhits
#                               
# TO DO:	
#

package QILTers::Analytics::dhits_View;

$VERSION = '0.5';

use strict;
use Carp;

use HTML::Template;
use Data::Dumper;
use webfuse::lib::View;

@QILTers::Analytics::dhits_View::ISA = ( qw/ View / );

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
  $self->{VIEW} = $args{VIEW} || "contentForumClicks";
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
#   -- need to get subset from both clickGrades and dHit
#   -- then construct pie chart based on 
#   -- TOTAL CLICKS - DHITS = content
#      DHITS = interaction
#   -- **** convert this to a %

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
    $self->{DHITS_DATA} = $self->{MODEL}->getSubset( $self->{VALUES}->{SUBSET} ) || [];
    $self->{CLICKS_DATA} = $self->{MODEL}->{CLICK_GRADES}->getSubset( $self->{VALUES}->{SUBSET} ) || [];

    my $count = @{$self->{DHITS_DATA}} ;
print "COUNT is $count\n";
    if ( $count != 0 ) {
        $self->plotly();
    }

    #-- now set up the rest of the page
 
    # Analytic name is title for the page
    # - course, offering, subset
    my $analyticName = "Content/Forum click % for " .
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
# - Need to
#   - add up all dhits_data
#   - add up all clicks data
#   - figure out the percentages
#   - generate plotly javascript
#   
#  Construct string
#       clicks which is comma separated list of % for clicks
#       - content and then forum
#       clicksLabels - Content, Forum 

sub plotly( ) {
    my $self = shift;

    #-- calcualte the percentages for contentClicks and forumClicks
    my $contentStats= $self->{MODEL}->getSubsetQuantStats( $self->{CLICKS_DATA} );
    my $forumStats = $self->{MODEL}->getSubsetQuantStats( $self->{DHITS_DATA} );;

    my $totalClicks = $contentStats->sum();
    my $forumClicks = $forumStats->sum();
    my $contentClicks = $totalClicks - $forumClicks;
    my $contentPerStudent = sprintf "%3.1f", $contentClicks / $contentStats->count();
    my $forumPerStudent = sprintf "%3.1f", $forumClicks / $contentStats->count();

    my $percent = 100 / $totalClicks;
    my $contentPercent = sprintf "%3.1f", $contentClicks * $percent;
    my $forumPercent = sprintf "%3.1f", $forumClicks * $percent;

    my $clicks = "$contentPercent, $forumPercent";
    my $clicksLabels = "\"Content (n=$contentClicks, c/p=$contentPerStudent)\", \"Forum (n=$forumClicks c/p=$forumPerStudent)\"";

    $self->{TEMPLATE}->param( clicks => $clicks );
    $self->{TEMPLATE}->param( clicksLabels => $clicksLabels );
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
