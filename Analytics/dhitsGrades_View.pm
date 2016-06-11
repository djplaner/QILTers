#
# FILE:		dhitsGrades_View.pm
# PURPOSE:	Construct a vertical bar chart of students grouped by grades
#           showing a bar chart showing # of content and forum clicks
#
# Let's try for
#                               
# TO DO:	
#

package QILTers::Analytics::dhitsGrades_View;

$VERSION = '0.5';

use strict;
use Carp;

use HTML::Template;
use Data::Dumper;
use webfuse::lib::View;

@QILTers::Analytics::dhitsGrades_View::ISA = ( qw/ View / );

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
  $self->{VIEW} = $args{VIEW} || "contentForumClicksGrades";
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
# - aim here is a horizontal bar graph with all students orderd by grade
# - y values can be the grades
#    HD - empty
#    empty - student count
#    ..
#    D - empty
#
# need to produce 
# - contentClicks - string containing 0 for each grade value and then
#   the # of content clicks for each student with the current grade
# - forumClicks - same by for forum clicks
# - yLabels - string containing "HD, '', '',....D,...."

sub plotly( ) {
    my $self = shift;

    #-- CLICKS_DATA and DHITS_DATA are arrays of hashes
    #   quantity
    #   EXTRAS->{grade} and ->{mark}

    #-- sort just CLICKS_DATA, can't do both because of orders

    my @sortedForumData = sort { 
                    $a->{EXTRAS}->{mark} <=> $b->{EXTRAS}->{mark} ||
                    $a->{quantity} <=> $b->{quantity} } 
                        @{$self->{DHITS_DATA}};

    #-- make hash by userid to access $self->{CLICKS_DATA} elements to combine
    my %contentHash = map { ( $_->{userid} => $_ ) } @{$self->{CLICKS_DATA}};

    #---- ***** initiall forget about the HD D stuff
    # - just join the forum clicks together, they are in order
    my @forumClicks = map { $_->{quantity} } @sortedForumData;
    my $forumClicks = join ", ", @forumClicks;

    my @contentClicks;
    my @labels;
    #--  content clicks isn't in same order as forum data, fix that
    my $count = 0;
    foreach my $user ( @sortedForumData ) {
        push @contentClicks, $contentHash{ $user->{userid}}->{quantity};
        push @labels, "\'$count $contentHash{ $user->{userid}}->{EXTRAS}->{grade}\'";
        $count++;
    }
    my $contentClicks = join ", ", @contentClicks;
    my $labels = join ", ", @labels;

    $self->{TEMPLATE}->param( forumClicks => $forumClicks,
                        contentClicks => $contentClicks, 
                        yLabels => $labels,
                        HEIGHT => $count * 10 );
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
    my $analytic = $self->{VALUES}->{ANALYTIC};
#    $analytic =~ s/^.*:://;

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
