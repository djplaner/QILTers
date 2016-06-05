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

my $model = QILTers::Analytics::clickGrades->new( OFFERING => "EDC3100_2015_1" );

print Dumper( $model );
