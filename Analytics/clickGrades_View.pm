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
# Display
#

sub Display {
    my $self = shift;
    my $string;

    return $self->DisplayError() 
        if ( ! defined $self->{MODEL} || $self->{MODEL}->Errors );

    return $self->DumpErrors()
        if ( ! $self->GetHTMLTemplate( 
                 "$self->{DIRECTORY}/$self->{VIEW}.$self->{FAMILY}" ) );

    #--- this is where we get the plot.ly data
    my $js = $self->plotly();

    $self->{TEMPLATE}->param( "PLOTLY" => $js ); 

    #-- now set up the rest of the page

    #-- set the parameters for standard stuff
    foreach my $field ( qw/ COURSE_NAME STUDENT_NAME COORDINATORS / ) {
        $self->{TEMPLATE}->param( $field => $self->{MODEL}->{$field} );
    }

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

    my $students = $self->{MODEL}->{BY_ROLE}->[0];
    #-- sort the clicks
    my @data = sort { $b->{quantity} <=> $a->{quantity} } @{$students} ;

    my @grades;

    #-- great grade array with list of clicks for each grade
    foreach my $grade ( qw/ HD A B C F / )  {
        #-- get the students with these grades
        my @array = grep { $_->{EXTRAS}->{grade} eq $grade } @{$students};
        @array = map { $_->{quantity} } @array;
        my $clicks = join ",", @array;
    #    $gradeClicks{$grade}  = \@array;

        push @grades, { grade => $grade,
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


1;
