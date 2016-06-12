#
# FILE:     postsNetwork.pl
# PURPOSE:  Simple test app for Analytics::postsNetwork.pm
#

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;
use Data::Dumper;

use webfuse::lib::QILTers::Analytics::postsNetwork;
use webfuse::lib::QILTers::Analytics::postsNetwork_View;


my $model = QILTers::Analytics::postsNetwork->new( OFFERING => "EDC3100_2015_2" );
#print Dumper( $model );
#die;
my $view  = QILTers::Analytics::postsNetwork_View->new( MODEL => $model );
my $string = $view->Display( 
                COURSE => "EDC3100", OFFERING => "2015_2",
                            SUBSET => "all" );

print $string;
