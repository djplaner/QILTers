#
# FILE:		clickGrades_View.pm
# PURPOSE:	View class for QILTers::Analytics::Details screen
#
# AUTHOR:	David Jones
# HISTORY:	15 July 2003
#     $Id: clickGrades_View.pm,v 1.3 2003/08/05 04:23:19 david Exp $
#                               
# TO DO:	
#

package QILTers::Analytics::clickGrades_View;

$VERSION = '0.5';

use strict;
use Carp;

use HTML::Template;
use Data::Dumper;
use webfuse::lib::View;

@QILTers::Analytics::clickGrades_View::ISA = ( qw/ View / );

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
  $self->{VIEW} = $args{VIEW} || "clickGrade";
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
# Display( SUBSET =>  COURSES => COURSE => OFFERING =>)
# - COURSES is the array of all we're doing
# - SUBSET COURSE and OFFERING are the specific one we're working on now

sub Display {
    my $self = shift;
    my %args = @_;

    $self->{VALUES} = \%args;

#print "**** VALUES \n";
#print Dumper( $self->{VALUES} );
#die;
    my $string;

    return $self->DisplayError() 
        if ( ! defined $self->{MODEL} || $self->{MODEL}->Errors );

    if ( ! $self->GetHTMLTemplate( 
                 "$self->{DIRECTORY}/$self->{VIEW}.$self->{FAMILY}" ) ) {
        print $self->DumpErrors();
        die; 
    }

    #-- point to the right subset of data
    $self->{DATA} = $self->{MODEL}->getSubset( $self->{VALUES}->{SUBSET} ) || [];


    my $count = @{$self->{DATA}} ;

    #   hard code to all students for now
#    $self->{DATA} = $self->{MODEL}->{BY_ROLE}->[0];

    #---- generate the view
    #--- this is where we get the plot.ly data
    if ( $count != 0 ) {
        my $js = $self->plotly();
        $self->{TEMPLATE}->param( "PLOTLY" => $js ); 
    }

    #-- now set up the rest of the page
 
    # Analytic name is title for the page
    # - course, offering, subset
    my $analyticName = "clicks/grade for " .$self->{VALUES}->{COURSE} . " " .
                       $self->{VALUES}->{OFFERING} . " " .
                       $self->{VALUES}->{SUBSET};
    $self->{TEMPLATE}->param( ANALYTIC_NAME => $analyticName );

    #-- set up the nav menus at top of page
    # - entire site structure
    $self->{TEMPLATE}->param( COURSES => $self->{COURSES} );
    # - menu for the offering - basically the subsets
    my $subsets = $self->constructSubsetsView();
    $self->{TEMPLATE}->param( SUBSETS => $subsets );

    return $self->{TEMPLATE}->output();
}

#-----------------------------------------------------------------
# plotly()
# - based on data in $self->{MODEL}->{DATA}
# - output javascript requirements for plotly
# - for each grade (in order)
#   {
#      y: [ ordered list of clicks ],
#      name: 'grade label',
#      boxpoints: 'all',
#      jitter: 0.3,
#      pointpos: -1.8,
#      type: 'box',
#   }


sub plotly( ) {
    my $self = shift;

    my $plotlyJS = "<script> var data = [ ";

    my $students = $self->{DATA};
    #-- sort the clicks
    my @data = sort { $b->{quantity} <=> $a->{quantity} } @{$students} ;

    my @grades;
#print Dumper( $students );
#die;

    #-- great grade array with list of clicks for each grade
    foreach my $grade ( qw/ HD A B C F / )  {
        #-- get the students with these grades
        my @array = grep { $_->{EXTRAS}->{grade} eq $grade } @{$students};
        #-- get the hover text
#**** NOT REALLY WORKING FOR NOW
        #   - gpa, plan, mode
#        my @hoverText = map { "\"$_->{EXTRAS}->{mode} $_->{EXTRAS}->{plan} $_->{EXTRAS}->{gpa}\"" } @{$students};

        #-- just get the clicks
        my @clicks = map { $_->{quantity} } @array;
        my $clicks = join ",", @clicks;
#        my $hoverText = join ",", @hoverText;

    #    $gradeClicks{$grade}  = \@array;

        push @grades, { grade => $grade,
#                        hover => $hoverText,
                        clicks => $clicks };
    }

    #-- get the no grade ones
    my @array = grep { ! defined $_->{EXTRAS}->{grade} } @{$students};
    @array = map { $_->{quantity} } @array;
    my $clicks = join ",", @array;
    push @grades, { grade => "NO",
                        clicks => $clicks };


    $self->{TEMPLATE}->param( grades => \@grades );
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
