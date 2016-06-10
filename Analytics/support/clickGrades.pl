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




my $model = QILTers::Analytics::clickGrades->new( OFFERING => "EDC3100_2015_1" );

print Dumper( $model );

my $view  = QILTers::Analytics::clickGrades_View->new( MODEL => $model );
my $string = $view->Display();

print $string;
