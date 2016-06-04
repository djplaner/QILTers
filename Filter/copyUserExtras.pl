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
my $SD_2015_CONFIG = "$DATA_DIR/StudyDesk2015.txt";

my $EXTRAS_DEFAULTS = {
    TABLE => "mdl_user_extras",
    FIELDS => "id,program,plan,gpa,completed_units,transferred_units,postal_code,birthdate,mode,acad_load",
    CONDITIONS => "id in ( {id} )"
};

my $USER_DEFAULTS = {
    TABLE => "mdl_user",
    FIELDS => "id,PHONE1,PHONE2",
    CONDITIONS => "id in ( {id} )"
};

my $COURSE_STUDENTS_DEFAULTS = {
    TABLE => "moodle.mdl_user u JOIN moodle.mdl_user_enrolments ue ON ue.userid = u.id JOIN moodle.mdl_enrol e ON e.id = ue.enrolid JOIN moodle.mdl_role_assignments ra ON ra.userid = u.id JOIN moodle.mdl_context ct ON ct.id = ra.contextid AND ct.contextlevel = 50 JOIN moodle.mdl_course c ON c.id = ct.instanceid AND e.courseid = c.id JOIN moodle.mdl_role r ON r.id = ra.roleid AND r.shortname = 'student'",
    FIELDS => "u.id AS userid, firstname,lastname,u.idnumber,email,username",
    CONDITIONS => "c.id={courseid} and e.status = 0 AND u.suspended = 0 AND u.deleted = 0 AND ue.status = 0" ,
    GROUP => "group by u.id",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my @OFFERINGS = ( qw/ 2015_S1 2015_S2 / );

#-- cycle through the offerings 
foreach my $offering ( @OFFERINGS ) {
    #-- get mdl_user data for all students in SD_2015 for the offering
    # - ??? how to do this
    getStudents( $courseId );

    #-- delete any data already in SD_2015 mdl_user_extras

    #-- get the old mdl_user_extras data 


    #-- modify it - add offering -- what about grade??
    #   -- could do the auto calculate here now


    #-- insert it

}



#-----------------------------------------------------------------
# getStudents( $courseid ) 
# - get list of students enrolled in course

sub getStudents( $ ) {
    my $course_id = shift;

    my $students = NewModel->new( %$COURSE_STUDENTS_DEFAULTS, CONFIG => $CONFIG,
                                  KEYS => { courseid => $course_id } );
    if ( $students->Errors() ) {
        print "*** ERROR getting students in course\n";
        print $students->DumpErrors();
        die;
    }

    return $students;
}
