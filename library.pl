
use strict;

use Statistics::Descriptive;

my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

my $COURSE_DISCUSSIONS_DEFAULTS = {
    TABLE => "moodle.mdl_forum_discussions",
    FIELDS => "id",
    CONDITIONS => "course={course}"
};

my $USER_COURSE_POSTS_DEFAULTS = {
    TABLE => "moodle.mdl_forum_posts",
    FIELDS => "userid,created,id,parent,subject,message,attachment",
    CONDITIONS => "discussion in ( {discussion} ) and userid={userid}"
};

my $COURSE_DETAILS_DEFAULTS = {
    TABLE => "moodle.mdl_course",
    FIELDS => "id, category,fullname,shortname,idnumber,summary",
    CONDITIONS => "shortname in ( {shortname} )",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};
    
my $CLICK_NEW_DEFAULTS = {
    TABLE => "moodle.mdl_logstore_standard_log",
    FIELDS => "courseid,count(*) as clicks",
    CONDITIONS => "courseid in ( {courseid} )",
    GROUP => "group by courseid",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $CLICK_OLD_DEFAULTS = {
    TABLE => "moodle.mdl_log",
    FIELDS => "course as courseid,count(*) as clicks",
    CONDITIONS => "course in ( {course} )",
    GROUP => "group by course",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $STUDENT_CLICK_NEW_DEFAULTS = {    
    TABLE => "moodle.mdl_logstore_standard_log",
    FIELDS => "userid,count(*)",
    CONDITIONS => "courseid={courseid} and userid in ( {userid} )",
    GROUP => "group by userid",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $STUDENT_CLICK_OLD_DEFAULTS = {
    TABLE => "moodle.mdl_log",
    FIELDS => "userid,count(*)",
    CONDITIONS => "course={course} and userid in ( {userid} )",
    GROUP => "group by userid",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $USERS_CLICK_DETAILS_OLD_DEFAULTS = {
    TABLE => "moodle.mdl_log",
    FIELDS => "userid,time as timecreated,module as component,action,url,info",
    CONDITIONS => "course={course} and userid in ( {userid} )",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};
my $USERS_CLICK_DETAILS_DEFAULTS = {
    TABLE => "moodle.mdl_logstore_standard_log",
    FIELDS => "userid,timecreated,component",
    CONDITIONS => "course={course} and userid in ( {userid} )",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $GRADE_DEFAULTS = {
    TABLE => "moodle.mdl_grade_grades",
    FIELDS => "userid,id,finalgrade",
    CONDITIONS => "itemid in ( {itemid} )",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $COURSE_STUDENTS_DEFAULTS = {
    TABLE => "moodle.mdl_user u JOIN moodle.mdl_user_enrolments ue ON ue.userid = u.id JOIN moodle.mdl_enrol e ON e.id = ue.enrolid JOIN moodle.mdl_role_assignments ra ON ra.userid = u.id JOIN moodle.mdl_context ct ON ct.id = ra.contextid AND ct.contextlevel = 50 JOIN moodle.mdl_course c ON c.id = ct.instanceid AND e.courseid = c.id JOIN moodle.mdl_role r ON r.id = ra.roleid AND r.shortname = 'student'",
    FIELDS => "u.id AS userid, firstname,lastname,u.idnumber,email,username",
    CONDITIONS => "c.id={courseid} and e.status = 0 AND u.suspended = 0 AND u.deleted = 0 AND ue.status = 0" ,
    GROUP => "group by u.id",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};

my $COURSE_TEACHERS_DEFAULTS = {
    TABLE => "moodle.mdl_user u JOIN moodle.mdl_user_enrolments ue ON ue.userid = u.id JOIN moodle.mdl_enrol e ON e.id = ue.enrolid JOIN moodle.mdl_role_assignments ra ON ra.userid = u.id JOIN moodle.mdl_context ct ON ct.id = ra.contextid AND ct.contextlevel = 50 JOIN moodle.mdl_course c ON c.id = ct.instanceid AND e.courseid = c.id JOIN moodle.mdl_role r ON r.id = ra.roleid AND r.shortname in ( 'teacher', 'crl', 'editingteacher', 'coursecreator', 'tutr', 'mkr', 'aex', 'mod', 'ctm', 'exm'  ) ",
    FIELDS => "u.id AS userid,r.name,firstname,lastname,u.idnumber,email,username",
    CONDITIONS => "c.id={courseid} and e.status = 0 AND u.suspended = 0 AND u.deleted = 0 AND ue.status = 0" ,
    GROUP => "group by u.id,r.name",
    CACHE => { namespace => "QILT", default_expires_in => "7 days" }
};


#------------------------------------------------------
# calculateTotals

sub calculateTotals( $ ) {
    my $grades = shift;

    my %students;

    foreach my $row ( @{$grades->{DATA}} ) {
        push @{$students{$row->{userid}}->{DATA}}, $row;

        $students{$row->{userid}}->{MARKS} += $row->{finalgrade};
    }

    foreach my $uid ( keys %students ) {
        $students{$uid}->{GRADE} = calculateGrade( $students{$uid}->{MARKS} );
    }
    
    return \%students;
}

sub calculateGrade( $ ) {
    my $mark = shift;

    if ( $mark >= 85 ) {
        return "HD";
    } elsif ( $mark >= 75 ) {
        return "A";
    } elsif ( $mark >= 65 ) {
        return "B";
    } elsif ( $mark >= 50 ) {
        return "C";
    } else {
        return "F";
    }
}

#------------------------------------------------------
# getGrades

sub getGrades( $$ ) {
    my $course = shift;

    my $items = $course->{ITEMS};

    my $grades = NewModel->new( %$GRADE_DEFAULTS, CONFIG => $CONFIG,
                    KEYS => { itemid => $items }  );

    if ( $grades->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $grades->DumpErrors();
        die;
    } 

    return $grades;
}


sub addStudentCount( $ ) {
    my $clicks = shift;

    #-- add in students and calculate students per course
    foreach my $course ( @{$clicks->{DATA}} ) {
        my $students = getStudents( $course->{courseid} );
        $course->{STUDENTS} = $students->NumberOfRows();
        $course->{CLICKS_PER_STUDENT} = $course->{clicks} / $course->{STUDENTS};
    }
    return $clicks;
}

#
# getStudents( $courseid ) 
# - get list of students enrolled in course

sub getStudents( $ ) {
    my $course_id = shift;

    my $students = NewModel->new( %$COURSE_STUDENTS_DEFAULTS, CONFIG => $CONFIG,
                                  KEYS => { courseid => $course_id } );
    if ( $students->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $students->DumpErrors();
        die;
    } 

    return $students;
}

#---------------------------------------------------------------------------
# getStudentsClicks( $course_id, $students, $term )
# - given a NewModel with list of students add in CLICKS

sub getStudentsClicks( $$$ ) {
    my $course_id = shift;
    my $students = shift;
    my $term = shift;  # this should just be "OLD" or empty/else

    my @ids = map { $_->{userid} } @{$students->{DATA}};

    my $default = $STUDENT_CLICK_NEW_DEFAULTS;
    my $keys = { courseid => $course_id, userid => \@ids };

    if ( $term =~ /OLD/ ) {
        $default = $STUDENT_CLICK_OLD_DEFAULTS ;
        $keys = { course => $course_id, userid => \@ids };
    }

    my $clicks = NewModel->new( %$default, CONFIG => $CONFIG,
                    KEYS => $keys);

    if ( $clicks->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $clicks->DumpErrors();
        die;
    }

    #-- no need to take the $clicks DATA { count => userid => }
    #   and insert it into $students->{DATA}
    my %userids = map { ( $_->{userid} => $_->{count} ) } @{$clicks->{DATA}} ;
#print Dumper( \%userids );
    foreach my $student ( @{$students->{DATA}} ) {
        $student->{CLICKS} = $userids{$student->{userid}};
    }

    return $students;
}


sub addStudentCount( $ ) {
    my $clicks = shift;

    #-- add in students and calculate students per course
    foreach my $course ( @{$clicks->{DATA}} ) {
        my $students = getStudents( $course->{courseid} );
        $course->{STUDENTS} = $students->NumberOfRows();
        $course->{CLICKS_PER_STUDENT} = $course->{clicks} / $course->{STUDENTS};
    }
    return $clicks;
}

#
# getStudents( $courseid ) 
# - get list of students enrolled in course

sub getStudents( $ ) {
    my $course_id = shift;

    my $students = NewModel->new( %$COURSE_STUDENTS_DEFAULTS, CONFIG => $CONFIG,
                                  KEYS => { courseid => $course_id } );
    if ( $students->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $students->DumpErrors();
        die;
    } 

    return $students;
}

#
# getTeachers( $courseid )
# - get a list of teachers associated with a course

sub getTeachers( $ ) {
    my $course_id = shift;

    my $teachers = NewModel->new( %$COURSE_TEACHERS_DEFAULTS, CONFIG => $CONFIG,
                                  KEYS => { courseid => $course_id } );
    if ( $teachers->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $teachers->DumpErrors();
        die;
    } 

    return $teachers;
}

#
# getUsersByRole( $@userData, $role )
# - given an array of user hash (one key is name) return just those
#   that match a role

sub getUsersByRole( $$ ) {
    my $users = shift;
    my $row = shift;

    my @data = grep { $_->{name} eq $row } @{$users};

    return \@data;
}

#
# getCourseClicks( $COURSES )
# - given an array of course ids, generate data about the clicks on 
#   those study desk

sub getCourseClicks( $$ ) {
    my $course_ids = shift;
    my $type = shift;

    my $default = $CLICK_NEW_DEFAULTS;
    my $keys = { courseid => $course_ids };

    if ( $type =~ /OLD/ ) {
        $default = $CLICK_OLD_DEFAULTS ;
        $keys = { course => $course_ids };
    }

    my $clicks = NewModel->new( %$default, CONFIG => $CONFIG,
                    KEYS => $keys  );

    if ( $clicks->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $clicks->DumpErrors();
        die;
    }

    return $clicks;
}

#
# getCourseDetails( $COURSES )
# - get ifnormation from mdl_courses for given list of courses given by
#   shorname

sub getCourseDetails( $ ) {
    my $course_shortnames = shift;

#print Dumper( $course_shortnames );
#die;
    my $keys = { shortname => $course_shortnames };

    my $courses = NewModel->new( %$COURSE_DETAILS_DEFAULTS, CONFIG => $CONFIG,
                    KEYS => $keys  );

    if ( $courses->Errors() ) {
        print "*** ERROR getting clicks\n";
        print $courses->DumpErrors();
        die;
    }

    return $courses;
}

#------------------------
# outputClicksGradesPlotly( $students )
# - given clicks and grades output # of clicks
#   output javascript requirement for plotly
# - for each grade (in order)
#   {
#      y: [ ordered list of clicks ],
#      name: 'grade label',
#      boxpoints: 'all',
#      jitter: 0.3,
#      pointpos: -1.8,
#      type: 'box',
#   }

sub outputClicksGradesPlotly( $ ) {
    my $students = shift;

    #-- sort the clicks
    my @data = sort { $b->{CLICKS} <=> $a->{CLICKS} } @{$students->{DATA}} ;

    #-- hash to contain arrays of ordered clicks for each grade
    my %gradeClicks;

    foreach my $grade ( qw/ HD A B C F / )  {
        #-- get the students with these grades
        my @array = grep { $_->{GRADE} eq $grade } 
                                    @{$students->{DATA}};
        @array = map { $_->{CLICKS} } @array;
        $gradeClicks{$grade}  = \@array;
        print "$grade: ";
        foreach my $click ( @{$gradeClicks{$grade}} ) {
            print "$click, ";
        } 
        print "\n";
    }
        
}        


#------------------------
# outputClicksAverages( $students )
# - given students NewModel output CSV file of 
#      $grade,average clicks,variance

sub outputClicksAverages($) {
    my $students = shift;

    my @data = sort { $a->{CLICKS} <=> $b->{CLICKS} } @{$students->{DATA}} ;

    my %averages;

    foreach my $row ( @data ) {
        print "$row->{username},$row->{GRADE},$row->{MARKS},$row->{CLICKS}\n";

        push @{$averages{$row->{GRADE}}}, $row->{CLICKS};

    }

    foreach my $grade ( qw/ HD A B C F / ) {
        my @tmp = grep { defined $_ } @{$averages{$grade}};
        my $stat = Statistics::Descriptive::Full->new();
        $stat->add_data( @tmp );
        printf "%s,%3.2f\n", $grade, $stat->mean() ;
    }

}

#------------------------
# outputStaffClicks( $courseShortName, $sstaff)
# - given staff NewModel output line
#   # staff,total clicks,average,stddev,variance,max,min

sub outputStaffClicks($$) {
    my $shortname = shift;
    my $staff = shift;

    my @data = map { $_->{CLICKS} } @{$staff->{DATA}} ;

    @data = grep { defined $_ } @data;

#print Dumper( \@data );
    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data( @data );
#print "count is " . $stat->count();

    printf "%s,%2d,%3.2f,%3.2f,%3.2f,%5d,%5d\n", $shortname, 
            $stat->count(),$stat->sum(),$stat->mean(),
            $stat->standard_deviation(),$stat->variance(),
            $stat->max(), $stat->min() ;

}

#-----------------------------------------------------------------
# getUserCoursePosts( $courseid, $userid )
# - given a course and user return details about all their posts to a course

sub getUserCoursePosts( $$ ) {  
    my $courseId = shift;
    my $userId = shift;

    #-- get the discussion ids first
    my $discussions = NewModel->new( %$COURSE_DISCUSSIONS_DEFAULTS, 
                        CONFIG => $CONFIG, 
                        KEYS => { course => $courseId } );

    if ( $discussions->Errors() ) {
        print "*** ERROR getting data\n";
        print $discussions->DumpErrors();
        die;
    }

    my @discussion_ids = map { $_->{id} } @{$discussions->{DATA}};

    #-- get the user posts
    my $userPosts = NewModel->new( %$USER_COURSE_POSTS_DEFAULTS, 
                        CONFIG => $CONFIG, 
                        KEYS => { discussion => \@discussion_ids,
                                  userid => $userId } );

    if ( $userPosts->Errors() ) {
        print "*** ERROR getting data\n";
        print $userPosts->DumpErrors();
        die;
    }

    return $userPosts;
}

