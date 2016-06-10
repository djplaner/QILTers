#
# FILE:     dhits.pl
# PURPOSE:  Simple test app for Analytics::dhits.pm
#

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;
use Data::Dumper;

use webfuse::lib::QILTers::Analytics::dhits;
use webfuse::lib::QILTers::Analytics::dhits_View;


my $model = QILTers::Analytics::dhits->new( OFFERING => "EDP4130_2015_1" );
print Dumper( $model );
foreach my $set ( qw/ all / ) {

    my $subset = $model->getSubset( $set );
    my $all = $model->getSubsetQuantStats( $subset );

    next if ( $all->count() == 0 );
print "**** SET $set\n";
foreach my $field ( qw/ count sum mean min max standard_deviation / ) {
    print "-- $field " . $all->$field() . "\n";
}
}
die;

#print Dumper( $model->{TOTAL_DHITS} );

my $view  = QILTers::Analytics::dhits_View->new( MODEL => $model );
my $string = $view->Display( 
                COURSE => "EDC3100", OFFERING => "2015_1",
                            SUBSET => "all" );

print $string;
