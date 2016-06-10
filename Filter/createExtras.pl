#
# FILE:     createExtras.pl
# PURPOSE:  Create new entries in mdl_user_extras for students in courses
#           that don't use it.
#    - for now just add in the grade data

BEGIN {
  push @INC, "/Library/Perl/5.8.1";
}

use strict;

use webfuse::lib::BAM::3100::MoodleUsers;
use Data::Dumper;

my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

require "$WEBFUSE_HOME/lib/QILTers/library.pl";

my $NEW_EXTRAS_DEFAULTS = {
    TABLE => "mdl_user_extras",
    FIELDS => "userid,course,term,year,mark,grade,gpa,program,plan,birthdate,mode,postal_code,completed_units,transferred_units,acad_load",
    CONDITIONS => "userid in ( {userid} )"
};

my %OFFERINGS = (  
     "EDS4250_2015_1" => { ITEMS => [ 27910, 27911 ] },
    "EDS4250_2015_2" => { ITEMS => [ 34824, 37108 ] },
     "EDC1400_2015_1" => { ITEMS => [26428, 26429, 26426, 32810 ] },
     "EDC1400_2015_2" => { ITEMS => [31520, 31518, 37225, 31519  ] },
   "EDS2401_2015_2" => { ITEMS => [ 32070, 32073, 32072, 32071 ] },
   "EDS2401_2015_1" => { ITEMS => [ 27889, 24992, 27888, 27887 ] },
    "EDX3160_2015_2" => { ITEMS => [ 37156, 37946, 36292 ] } ,
   "EDX3270_2015_1" => { ITEMS => [27686, 27687 ] },
   "EDX3270_2015_2" => { ITEMS => [30969, 30970 ] },
     "EDC4000_2015_2" => { ITEMS => [37226,34377,33869] },
     "EDC4000_2015_1" => { ITEMS => [25124,28088,28133] },
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
#    $students = getExtras( $students );
#print Dumper( $students );
#die;

    #-- modify it - add offering -- what about grade??
    #   -- could do the auto calculate here now
    $students = modifyStudents( $students, $offering->{shortname} );
#print Dumper( $students->{DATA} );
#die;

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

