#
# FILE:     dhitsGrades.pl
# PURPOSE:  Simple test app for Analytics::dhitsGrades.pm
#

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;
use Data::Dumper;

use webfuse::lib::QILTers::Analytics::dhits;
use webfuse::lib::QILTers::Analytics::dhitsGrades_View;


my $model = QILTers::Analytics::dhits->new( OFFERING => "EDP4130_2015_1" );
print Dumper( $model );
#foreach my $set ( qw/ all / ) {

#    my $subset = $model->getSubset( $set );
#    my $all = $model->getSubsetQuantStats( $subset );

#    next if ( $all->count() == 0 );
#print "**** SET $set\n";
#foreach my $field ( qw/ count sum mean min max standard_deviation / ) {
#    print "-- $field " . $all->$field() . "\n";
#}
#}
#die;

#print Dumper( $model->{TOTAL_DHITS} );

my $view  = QILTers::Analytics::dhitsGrades_View->new( MODEL => $model );
my $string = $view->Display( 
                COURSE => "EDP4130", OFFERING => "2015_1",
                            SUBSET => "mode=Toowoomba,grade=F" );

print $string;
