#
# FILE:     rossiHits.pl
# PURPOSE:  Add into qilt_quantities rows of the format
#
#   - USER DHITS is # of clicks on discussion forums (and perhaps others)
#   - all for a student of a staff member can be added up to get totals
#   - can use TOTAL CLICKS to get overall percentage
#   
# ?? Is a forum the only place such an interaction can occur?
#   

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;

use webfuse::lib::BAM::3100::MoodleUsers;
use Data::Dumper;

my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

require "$WEBFUSE_HOME/lib/QILTers/library.pl";

my $QILT_Q_DEFAULTS = {
    TABLE => "qilt_quantities",
    FIELDS => "userid,roleid,course,term,year,q_type,quantity",
    CONDITIONS => "course={course} and term={term} and year={year} and " .
                  "q_type={q_type}"
};

#my @OFFERINGS = (  qw/ EDC3100_2015_1 EDC3100_2015_2 / );
my @OFFERINGS = (  qw/ EDS4250_2015_1 EDS4250_2015_2 EDC1400_2015_1
EDC1400_2015_2 EDS2401_2015_2 EDS2401_2015_1 EDX3160_2015_2 EDX3270_2015_1
EDX3270_2015_2 EDC4000_2015_2 EDC4000_2015_1 / );

my $ids = getCourseDetails( \@OFFERINGS );

if ( $ids->NumberOfRows == 0 ) {
    die "Didn't find any matching offerings\n";
}

#-- cycle through the offerings 
foreach my $offering ( @{$ids->{DATA}} ) {
    my $clicks = getUsersClicks( $offering->{id}, $offering->{shortname}, "DHITS" );
    #-- return hash with fields count and userid

    #-- convert the clicks into the data we want to submit
    my @offering = split /_/, $offering->{shortname};
    my @data;
    foreach my $user ( @{$clicks} ){
        my $data = { userid => $user->{userid},
                     roleid => $user->{roleid},
                     course => $offering[0],
                     year => $offering[1],
                     term => $offering[2],
                     q_type => "USER DHITS",
                     quantity => $user->{count} };
        push @data, $data;
    }

    insertQuantities( \@data );
}


#----------------------------------------------------
# insertQuantities( \@data )
# - given some data, stick it into qilt_quantities - remove any matching data
#   first

sub insertQuantities( $ ) {
    my $data = shift;

    my $q = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $QILT_Q_DEFAULTS,
                KEYS => $data->[0] );

#print Dumper( $q->{DATA} );
#die;
    #-- delete any existing data from mdl_users_extra
    if ( $q->NumberOfRows() > 0 ) {
        $q->delete();
        $q->{DATA} = [];
    }

    #-- insert the new data
    $q->{DATA} = $data;
#    $q->{DEBUG} = 2;

    $q->Insert();

    if ( $q->Errors() ) {
        $q->DumpErrors();
        die;
    }
}
