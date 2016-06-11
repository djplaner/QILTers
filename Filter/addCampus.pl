#
# FILE:     addCampus.pl
# PURPOSE:  Add the campus to mdl_user_extras for each user in a set of 
#           of offerings using contents of mdl_groups and mdl_groups_members

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
    CONDITIONS => "course={course} and term={term} and year={year} and mode is NULL"
};

my $USERID_GROUPNAME = {
    TABLE => "moodle.mdl_groups as groups,moodle.mdl_groups_members as members",
    FIELDS => "userid,name",
    CONDITIONS => "groups.id=groupid and courseid={courseid} and " .
                  "userid in ( {userid} ) and " . 
                  "( name like 'On-Campus%' or name like 'Online%' ) "
};

my @OFFERINGS = (  qw/ EDP4130_2015_1 EDS4250_2015_2 EDS4250_2015_2 EDC1400_2015_1
     EDC1400_2015_2 EDS2401_2015_2 EDS2401_2015_1 EDX3160_2015_2
   EDX3270_2015_1 EDX3270_2015_2 EDC4000_2015_2 EDC4000_2015_1 /
 );

my $ids = getCourseDetails( \@OFFERINGS );

if ( $ids->NumberOfRows == 0 ) {
    die "Didn't find any matching offerings\n";
}

#-- cycle through the offerings 
foreach my $offering ( @{$ids->{DATA}} ) {
    #$offering->{ITEMS} = $OFFERINGS{$offering->{shortname}};

#print Dumper( $offering );
    #-- get the user_extras details for those with no campus
    my $extras = getNoCampusExtras( $offering->{shortname} );
    
    if ( $extras->NumberOfRows() == 0 ) {
        print "$offering->{shortname} nothing found\n";
        next;
    }

    #-- get the data on Moodle groups to the extras
    $extras = addGroups( $extras, $offering->{id} );
#print Dumper( $extras->{DATA} );
#die;

    #-- delete any data already in SD_2015 mdl_user_extras
    #-- insert the new data
    updateExtras( $extras );
}

#-----------------------------------------------------------------
# getNoCampusExtras
# - given a shortname, get the users with no campus set in extras

sub getNoCampusExtras( $ ) {
    my $offering = shift;

    my @offering = split /_/, $offering;

    my $extras = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $NEW_EXTRAS_DEFAULTS,
                KEYS => { course => $offering[0], year => $offering[1],
                          term => $offering[2] } );
    
    if ( $extras->Errors() ) {
        $extras->DumpErrors();
        die;
    }

    return $extras;
}

#-----------------------------------------------------------------
# updateExtras
# - given NewModel of mdl_user_extras table
# - update the table with new mode

sub updateExtras( $ ) {
    my $extras = shift;

    $extras->{CONDITIONS} = "course={course} and term={term} and year={year} and userid={userid}";

#print Dumper( $extras );
#die;

    $extras->{DEBUG} = 0;

    $extras->Update( qw/ mode / );
    
}

#-----------------------------------------------------------------
# addGroups( $extras, $courseid )
# - given NewModel with extras for a course by courseid
# - extract the group membership for users in the course
# - and update the mode field in extras->{DATA}
# - return that

sub addGroups( $$ ) {
    my $extras = shift;
    my $courseid = shift;

    #-- get array of hashes { userid => name => }
    #   where name is the groupname
    my @userids = map { $_->{userid} } @{$extras->{DATA}};

    my $groups = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $USERID_GROUPNAME,
                KEYS => { courseid => $courseid, userid => \@userids }, 
                DEBUG => 1 );
    
    if ( $groups->Errors() ) {
        $groups->DumpErrors();
        die;
    }

    #-- create a hash by userid and use it to update extras
    my %userGroup = map { ( $_->{userid} => $_ ) } @{$groups->{DATA}};

    foreach my $row ( @{$extras->{DATA}} ) {
        if ( exists $userGroup{$row->{userid}} ) {
            my $name = $userGroup{$row->{userid}}->{name};

            if ( $name =~ /^On-Campus - (.*) - T.*$/ ) {
                $row->{mode} = $1;
            } elsif ( $name =~ /^On-Campus - (.*)$/ ) {
                $row->{mode} = $1;
            } elsif ( $name eq "Online" ) {
                $row->{mode} = $name;
            }
        }
    }
    
    return $extras;
}

