#
# FILE:     copyUserExtras.pl
# PURPOSE:  Copy mdl_user_extras content from old EDC3100 databases
#           into the new analytics StudyDesk2015 database

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

my $OLD_USERS = {
    TABLE => "mdl_user",
    FIELDS => "id,email,firstname,lastname",
    CONDITIONS => "email in ( {email} ) "
};

my $EXTRAS_DEFAULTS = {
    TABLE => "mdl_user_extras",
    FIELDS => "id,program,plan,gpa,completed_units,transferred_units,postal_code,birthdate,mode,acad_load",
    CONDITIONS => "id in ( {id} )"
};

my $NEW_EXTRAS_DEFAULTS = {
    TABLE => "mdl_user_extras",
    FIELDS => "userid,course,term,year,mark,grade,gpa,program,plan,birthdate,mode,postal_code,completed_units,transferred_units,acad_load",
    CONDITIONS => "userid in ( {userid} )"
};

my %OFFERINGS = (  
    EDC3100_2015_1 => { ITEMS => [ 28535, 28536, 28537, 26097 ] },
    EDC3100_2015_2 => { ITEMS => [ 32829, 32831, 32828, 32826] }
 );

my @offerings = keys %OFFERINGS;
my $ids = getCourseDetails( \@offerings );

if ( $ids->NumberOfRows == 0 ) {
    die "Didn't find any matching offerings\n";
}

#-- cycle through the offerings 
foreach my $offering ( @{$ids->{DATA}} ) {
    $offering->{ITEMS} = $OFFERINGS{$offering->{shortname}};

    #-- get mdl_user data for all students in SD_2015 for the offering
    # - includes firstname, email, idnumber, userid, lastname, username
    my $students = getStudents( $offering->{id} );

    #-- add the grades as calculated from moodle gradebook
    $students = addGrades( $students, $offering->{ITEMS} );
#print Dumper( $students->{DATA} );

    #-- get the old mdl_user_extras data 
    $students = getExtras( $students );
#print Dumper( $students );

    #-- modify it - add offering -- what about grade??
    #   -- could do the auto calculate here now
    $students = modifyStudents( $students, $offering->{shortname} );

    #-- delete any data already in SD_2015 mdl_user_extras
    #-- insert the new data
    insertStudents( $students );
}

#-----------------------------------------------------------------
# addGrades( $students, $ITEMS)
# - given an array of students and list of grade item ids 
#   - get their grades and add them to the arra

sub addGrades( $$ ) {
    my $students = shift;
    my $items = shift;

    my $grade_items = getGrades( $items );

#    print Dumper( $grade_items->{DATA} );

    my $results = calculateTotals( $grade_items );

#    print Dumper( $results );

    foreach my $student ( @{$students->{DATA}} ) {
        $student->{MARKS} = $results->{$student->{userid}}->{MARKS};
        $student->{GRADE} = $results->{$student->{userid}}->{GRADE};
    }

    return $students;
}

#-----------------------------------------------------------------
# getExtras( $students )
# - given list of students get their entries from mdl_users_extras
# - and add them into $students

sub getExtras( $ ) {
    my $students = shift;
    my %emails = map { ( $_->{email} => $_ ) } @{$students->{DATA}} ;
    my @emails = keys %emails;

    #-- need to get old moodle user id for given students
    # - select * from mdl_user where email= email
    my $userids = NewModel->new( CONFIG => $EDC3100_CONFIG,
                DEFAULTS => $OLD_USERS,
                KEYS => { email => \@emails } );

    #-- ??? what sort of hash to create here
    my %oldIds = map { ( $_->{userid} => $_ ) } @{$userids->{DATA}};
    my @ids = keys %oldIds;

    #-- use the old ids to get the content from mdl_users_extras
    my $extras = NewModel->new( CONFIG => $EDC3100_CONFIG,
                DEFAULTS => $EXTRAS_DEFAULTS,
                KEYS => { userid => \@ids } );

    #-- insert the users_extras back into students
    for my $oldStudent ( @{$extras->{DATA}} ) {
        # we have id
        my $email = $oldIds{ $oldStudent->{userid} }->{email};
        $emails{$email}->{EXTRAS} = $oldStudent;
    }
    return $students;
}

#-----------------------------------------------------------------
# modifyStudents( $students, $shortname )
# - given a NewModel of students and an offering shortname
# - modify the extras array for each student by
#   - adding offering
#   - adding marks and grades
#   - modifying id to use new moodle id

sub modifyStudents( $$ ) {
    my $students = shift;
    my $shortname = shift;

    my @missing;
    my @offering = split /_/, $shortname;
    foreach my $student ( @{$students->{DATA}} ) {
        if ( ! exists $student->{EXTRAS} ) {
            print Dumper( $student );
            push @missing, $student;
#            die "Unable to find extras for...";
        }

        my $extras = $student->{EXTRAS};
        #-- add offering details
        $extras->{course} = $offering[0];
        $extras->{year} = $offering[1];
        $extras->{term} = $offering[2];

        #-- add mark and grade
        $extras->{mark} = $student->{MARKS};
        $extras->{grade} = $student->{GRADE};

        #-- update Moodle id
        $extras->{userid} = $student->{userid}; 

        #-- put limited info for those we're missing more
        if ( ! exists $student->{EXTRAS} ) {
            $student->{EXTRAS} = $extras;
        }
    }
    return $students;
}

#-----------------------------------------------------------------
# insertStudents( $students )
# - given NewModel of students with each student having a field EXTRAS
#   that contains content from old Webfuse mdl_user_extras
# - insert the extras information into new mdl_user_extras


sub insertStudents( $ ) {
    my $students = shift;

    #-- get the ids for these students 
    my @ids = map { $_->{userid} } @{$students->{DATA}} ;

    my $extras = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $NEW_EXTRAS_DEFAULTS,
                KEYS => { id => \@ids }, DEBUG => 1 );

    
#print Dumper( $extras );
#die;
    #-- delete any existing data from mdl_users_extra
    $extras->delete();
    $extras->{DATA} = [];

    #-- insert the new data
    @{$extras->{DATA}} = map { $_->{EXTRAS} } @{$students->{DATA}};

    $extras->Insert();
}

