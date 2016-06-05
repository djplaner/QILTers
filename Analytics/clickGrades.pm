#
# FILE:		BAM::3100::MoodleUsers.pm
# PURPOSE:	Model to generate statistics about 3100 blogs from a BIM
#           database
#
#	Two constructors
#	new - gets all user details
#
# AUTHOR:	David Jones
# HISTORY:	18 March 2013	Started
#           26 March 2016   Added findByName()
#
# TO DO:	
#

package BAM::3100::MoodleUsers;

$VERSION = '0.5';

use strict;

use Data::Dumper;

use webfuse::lib::NewModel;

@BAM::3100::MoodleUsers::ISA = ( "NewModel" );

#--------------------
# Globals

use webfuse::lib::WebfuseConfig;
my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
#my $CONFIG = "$DATA_DIR/moodle.txt";
my $CONFIG = "$DATA_DIR/NewMoodle.txt";

my $BAM_DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/BAM";

# CONDITIONS is constructed in handle_params based on parameters
# passed in

my $EDC3100_2014_S1_defaults = {
  TABLE => "mdl_user",
  FIELDS => "id,username,firstname,lastname,email,phone1,idnumber,usqmoodleid",
  CONDITIONS => "id in ( select distinct userid from mdl_groups_members where groupid in (26, 29,28,36,25,31,24 ,38 ,32 ,27 ,30 ,34 ,33 ,41 ,35 ,37 ,44 ,45 ,40 ,42 ,39 ,43) )"
};

my $defaults = {
  TABLE => "mdl_groups_members,mdl_groups,mdl_user",
  FIELDS => "mdl_user.id,username,firstname,lastname,email,phone1,mdl_user.idnumber,usqMoodleId",
  CONDITIONS => "mdl_groups.courseid={COURSE_ID} and mdl_groups.id in ( {GROUP_ID} ) and mdl_groups_members.groupid=mdl_groups.id and mdl_user.id=mdl_groups_members.userid group by mdl_user.id" 
   #-- saving was working
  #CONDITIONS => "mdl_groups.courseid={COURSE_ID} and mdl_groups_members.id in ( {GROUP_ID} ) and mdl_groups_members.groupid=mdl_groups.id and mdl_user.id=mdl_groups_members.userid group by mdl_user.id" 
};

my @REQUIRED_PARAMETERS = ( qw/ COURSE_ID GROUP_ID / );

my %TRANSLATE_PARAMETERS = (
    "EDC3100" => {
#        "2014_S1" => { COURSE_ID => 3,  GROUP_ID => [26, 29,28,36,25,31,24 ,38 ,32 ,27 ,30 ,34 ,33 ,41 ,35 ,37 ,44 ,45 ,40 ,42 ,39 ,43 ] },
        "2014_S2" => { COURSE_ID => 4, GROUP_ID => [46] },
        "2015_S1" => { COURSE_ID => 3, GROUP_ID => [27] },
        "2015_S2" => { COURSE_ID => 5, GROUP_ID => [53] },
        "2016_S1" => { COURSE_ID => 15, GROUP_ID => [176] }
    },
    "EDU8117" => {
        "2014_S2" => { COURSE_ID => 5, GROUP_ID => [68] },
        "2015_S2" => { COURSE_ID => 6, GROUP_ID => [26] }
    }
);


#----------
# Database parameters to get data from mdl_user_extras

my $EXTRAS_DEFAULTS = {
    TABLE => "mdl_user_extras",
    FIELDS => "id,program,plan,gpa,completed_units,postal_code,birthdate,mode,dropped_course",
    CONDITIONS => " id in (ID)"
};

my @EXTRAS_REQUIRED_PARAMETERS = ( qw/ ID / );


#-------------------------------------------------------------
# new(  )

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
    
  my %args = @_;

  bless( $self, $class );

  return $self if ( ! $self->HandleParams( %args ) );

  $self->createUIDhash();
  return $self;
}

#---------------------------------------------------------------------------
# HandleParams
# - check the parameters passed in

sub HandleParams
{
  my $self = shift;
  my %args = @_;

  #-- setup the defaults
  %{$self->{DEFAULTS}} = %$defaults;
  @{$self->{REQUIRED_PARAMETERS}} = @REQUIRED_PARAMETERS;
  $self->{CONFIG} = $args{CONFIG} || $CONFIG;

  #-- have we got COURSE and TERM - can we get COURSE_ID GROUP_ID
  my $course = $args{COURSE};   my $term = $args{TERM};

  if ( exists $TRANSLATE_PARAMETERS{$course}->{$term} ) {
        $args{COURSE_ID} = $TRANSLATE_PARAMETERS{$course}->{$term}->{COURSE_ID}; 
        $args{GROUP_ID} = $TRANSLATE_PARAMETERS{$course}->{$term}->{GROUP_ID}; 
  }

  return $self->SUPER::HandleParams( %args );
}


#-----------------------------------------------------------------
# createUIDhash
# - create hash into data with key phone1
# - add in IDNUMBER as well

sub createUIDhash
{
  my $self = shift;

  foreach my $row ( @{$self->{DATA}} )
  {
    $self->{UIDS}->{$row->{id}} = $row;
    $self->{IDNUMBER}->{$row->{idnumber}} = $row;
    $self->{USQ}->{$row->{usqmoodleid}} = $row;
    $self->{EMAIL}->{$row->{email}} = $row;
  }
}

#-----------------------------------------------------------------
# addExtras
# - add to DATA the information from the table mdl_user_extras
#   for each user

sub addExtras {
    my $self = shift;

    $self->createUIDhash() if ( ! exists $self->{UIDS} );

    #-- get the userids
    my @userIds = keys %{$self->{UIDS}};

    #-- extra that data from the database
    my $model = NewModel->new( CONFIG => $CONFIG,
                                DEFAULTS => $EXTRAS_DEFAULTS,
                          REQUIRED_PARAMETERS => \@EXTRAS_REQUIRED_PARAMETERS,
                                ID => \@userIds, DEBUG => 1 );


    if ( $model->Errors() ) {
        print "****ERROR Can't get data - addExtras\n";
        $model->DumpErrors();
    }

    #-- merge the extras data into DATA
    foreach my $row ( @{$model->{DATA}} ) {
        if ( exists $self->{UIDS}->{$row->{id}} ) {
            foreach my $key ( qw/ birthdate mode program postal_code
                                     completed_units gpa plan /  ) {
                $self->{UIDS}->{$row->{id}}->{$key} = $row->{$key};
            }
        }
    }

    #-- create a hash PLAN based on the plan
    # - Program == "BEarly Childhood" - go to 'EarlyChild'
    # - Plan can be 'Seconday+????'  '* Secondary'
    PLAN: foreach my $row ( @{$self->{DATA}} ) {

        if ( $row->{program} eq "BVocationalEduc&Training" ) {
            push @{$self->{PLAN}->{VET}}, $row;
            next PLAN;
        } 

        if ( $row->{program} eq "BEarly Childhood" || 
             $row->{program} eq "BECH" ) {
            push @{$self->{PLAN}->{EarlyChild}}, $row;
            next PLAN;
        } 
        if ( ! exists ( $row->{plan} ) || $row->{plan} eq "" ) {
            push @{$self->{PLAN}->{NOPLAN}}, $row;
            next PLAN;
        }
        
        #-- secondary students
        if ( $row->{plan} =~ m#Secondary# ||
             $row->{plan} =~ m#Secondy# ||
             $row->{plan} =~ m#Secondry# ) {
            push @{$self->{PLAN}->{Secondary}}, $row;
            if ( $row->{plan} =~ m#Health & PE# ) {
                push @{$self->{PLAN}->{HPE}}, $row;
            }
            next PLAN;
        }
             
        if ( $row->{plan} =~ m#Sport, Health & PE# ) {
            push @{$self->{PLAN}->{HPE}}, $row;
            
            if ( $row->{plan} =~ m#\+Primary# ) {
                push @{$self->{PLAN}->{Primary}}, $row;
            } elsif ( $row->{plan} =~ m#\+Secondary# ) {
                push @{$self->{PLAN}->{Secondary}}, $row;
            }
            next PLAN;
        }

        foreach my $plan ( qw/ SpecEduc Primary EarlyChild / ) {
            if ( $row->{plan} =~ m#$plan# ) {    
                push @{$self->{PLAN}->{$plan}}, $row;
                next PLAN;
            }
        }

        push @{$self->{PLAN}->{NOPLAN}}, $row;
#        print Dumper( $row );
 #       die "MoodleUsers::AddExtras - NO match up plan\n";
    }
}

#-----------------------------------------------------------------
# findByName( $surname, $firstname )
# - given a surname and firstname return the DATA row that matches
# - WTF happens when there's a duplicate name???

sub findByName {
    my $self = shift;
    my $surname = shift;
    my $firstname = shift; 

    foreach my $row ( @{$self->{DATA}} ) {

        if ( $row->{lastname} =~ /^$surname$/i &&
             $row->{firstname} =~ /^$firstname$/i ) {
            return $row;    
        }
    }
    return 0;
}

1;


