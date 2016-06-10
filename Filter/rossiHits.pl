#
# FILE:     clickGrades.pl
# PURPOSE:  Calculate the total number of clicks in a course site for
#           all users of that course and add an entry for each user
#           into the qilt_quantities table
#           q_type = TOTAL CLICKS

BEGIN
{
  push @INC, "/Library/Perl/5.8.1";
}

use strict;

use webfuse::lib::BAM::3100::MoodleUsers;
use Data::Dumper;

my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $EDC3100_CONFIG = "$DATA_DIR/NewMoodle.txt";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

require "$WEBFUSE_HOME/lib/QILTers/library.pl";

my $QILT_Q_DEFAULTS = {
    TABLE => "qilt_quantities",
    FIELDS => "userid,roleid,course,term,year,q_type,quantity",
    CONDITIONS => "course={course} and term={term} and year={year} and " .
                  "q_type={q_type}"
};

my @OFFERINGS = (  qw/ EDC3100_2015_1 EDC3100_2015_2 / );

my $ids = getCourseDetails( \@OFFERINGS );

if ( $ids->NumberOfRows == 0 ) {
    die "Didn't find any matching offerings\n";
}

#-- cycle through the offerings 
foreach my $offering ( @{$ids->{DATA}} ) {
    my $clicks = getUsersClicks( $offering->{id}, $offering->{shortname} );
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
                     q_type => "TOTAL CLICKS",
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
