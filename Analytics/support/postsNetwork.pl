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


my $model = QILTers::Analytics::postsNetwork->new( OFFERING => "EDC3100_2015_1" );


#-- testing getSubset
my $data = $model->getSubset(# ) ; #-- all of them
#            "forum=49765"  );  #-- posts in a specific forum
#            "forum=57586"  );  #-- posts in a specific forum
            #"forum=57586,mode=Toowoomba"  );  #-- posts in a specific forum
            "mode=Springfield,forum=57586"  );  #-- posts in a specific forum
        # 
print Dumper( $data );

my $count = @$data;
print "Found $count posts\n";
#print Dumper( $model->{FORUMS} );
die;
my $view  = QILTers::Analytics::postsNetwork_View->new( MODEL => $model );
my $string = $view->Display( 
                COURSE => "EDC3100", OFFERING => "2015_1",
                            SUBSET => "49765" );

print $string;
