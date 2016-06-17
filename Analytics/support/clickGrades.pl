#
# FILE:     clickGrades.pl
# PURPOSE:  Simple test app for Analytics::clickGrades.pm
#

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;
use Data::Dumper;

use webfuse::lib::QILTers::Analytics::clickGrades;
use webfuse::lib::QILTers::Analytics::clickGrades_View;

my %COURSES = ( qw/ EDC3100 =>  {
                "2015_1" => { clickGrades => [ all ] } } / );


my $model = QILTers::Analytics::clickGrades->new( OFFERING => "EDC3100_2015_1" );

#my $subset = $model->getSubset( "mode=Online" );
#my $subset = $model->getSubset( "grade=F,mode=Online" );
#print Dumper( $subset );

my $view  = QILTers::Analytics::clickGrades_View->new( MODEL => $model );
my $string = $view->Display(
                        SUBSET => "mode=Fraser Coast,grade=B",
                        ANALYTIC => "clickGrades", COURSE => "EDC3100", OFFERING => "EDC3100_2015_1");

print $string;
