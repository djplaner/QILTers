#
# FILE:		QILTers::Analytics::clickGrades.pm
# PURPOSE:	Model to map clickGrades (and various filters) for a given course
#
#   $model = $$->new( OFFERING => "EDC3100_2015_1", Q_TYPE =>  );
#   - gather user demographic data for that offering
#     - includes grades 
#   - gather total clicks
#     - include role
#
#   - merge all this into a single array hash
#   - allow calling scripts to chop and change
#
#
# TO DO:	
#

package QILTers::Analytics::clickGrades;

$VERSION = '0.5';

use strict;

use Data::Dumper;

use webfuse::lib::NewModel;

@QILTers::Analytics::clickGrades::ISA = ( "NewModel" );

#--------------------
# Globals

use webfuse::lib::WebfuseConfig;
my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

# CONDITIONS is constructed in handle_params based on parameters
# passed in

my $QILT_Q_DEFAULTS = {
    TABLE => "qilt_quantities",
    FIELDS => "userid,roleid,course,term,year,q_type,quantity",
    CONDITIONS => "course={course} and term={term} and year={year} and " .
                  "q_type={q_type}"
};

my $EXTRAS_DEFAULTS = {
    TABLE => "mdl_user_extras",
    FIELDS => "userid,course,term,year,mark,grade,gpa,program,plan,birthdate,mode,postal_code,completed_units,transferred_units,acad_load",
    CONDITIONS => "course={course} and term={term} and year={year}"
};

my @REQUIRED_PARAMETERS = ( qw/ OFFERING course term year q_type / );


#-------------------------------------------------------------
# new(  )

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    
    my %args = @_;

    bless( $self, $class );

    #-- start with QILT quantities data as this one will be more inclusive
    # - teaching staff may not have anything in mdl_user_extras
    return $self if ( ! $self->HandleParams( %args ) );

    #-- get the mdl_user_extras ******
    $self->addUserExtras();
 
    #-- set up different sub-arrays based on roleid
    $self->setUpRoleData();

    return $self;
}

#---------------------------------------------------------------------------
# HandleParams
# - check the parameters passed in

sub HandleParams {
    my $self = shift;
    my %args = @_;

#print Dumper( \%args );
#die;
    #-- setup the defaults
    if ( exists $args{DEFAULTS} ) {
        %{$self->{DEFAULTS}} = %{$args{DEFAULTS}};
    } else {
        %{$self->{DEFAULTS}} = %$QILT_Q_DEFAULTS;
    }

    if ( exists $args{REQUIRED_PARAMETERS} ) {
        @{$self->{REQUIRED_PARAMETERS}} = @{$args{REQUIRED_PARAMETERS}};
    } else {
        @{$self->{REQUIRED_PARAMETERS}} = @REQUIRED_PARAMETERS;
    }
    $self->{CONFIG} = $args{CONFIG} || $CONFIG;

    if ( ! exists $args{q_type} )  {
        $args{q_type} = "TOTAL CLICKS"; 
    }

    #-- convert OFFERING into elements
    if ( exists $args{OFFERING} ) {
        my @offerings = split /_/, $args{OFFERING};
        $args{course} = $offerings[0];
        $args{year} = $offerings[1];
        $args{term} = $offerings[2];

        $self->{OFFERING}->{course} = $offerings[0];
        $self->{OFFERING}->{year} = $offerings[1];
        $self->{OFFERING}->{term} = $offerings[2];
    }
 
    return $self->SUPER::HandleParams( %args );
}


#---------------------------------------------------------------------------
# addUserExtras
# - add into DATA an entry EXTRAS with data mdl_user_extras table
#   where available (not for staff)

sub addUserExtras() {
    my $self = shift;

    my $keys = $self->{OFFERING};

    my $q  = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $EXTRAS_DEFAULTS,
                KEYS => $keys );

    if ( $q->Errors() ) {
        $q->DumpErrors();
        die;
    }
    if ( $q->NumberOfRows() == 0 ) {
        print "No user extras data found\n";
        print Dumper( $keys );
        die;
    }

    #-- create a hash into $q->{DATA} based on userid
    my %userId = map { ( $_->{userid} => $_ ) } @{$q->{DATA}};

    #-- merge qilt data into $self->{DATA}
    foreach my $row ( @{$self->{DATA}} ) {
        $row->{EXTRAS} = $userId{ $row->{userid} };
#        $row->{roleid} = $userId{ $row->{userid} }->{roleid};
    }
}

#---------------------------------------------------------------------------
# $self->setUpRoleData();
# - create array BY_ROLE 
# - each element contains an array of hashes based on roleid
#   - 0 - student, 1 - teacher

sub setUpRoleData() {
    my $self = shift;

    $self->{BY_ROLE} = [];

    foreach my $role( qw/ 0 1 / ) {
        #-- extract rows matching
        @{$self->{BY_ROLE}->[$role]} = grep { $_->{roleid} == $role } 
                                            @{$self->{DATA}};
    }
}

#---------------------------------------------------------------------------
# @{$students} = getSubset( $subset )
# - return a subset of data from this model based on the $subset
# - all - all students
# - Online, Springfield, Toowoomba, Fraser Coast - enrolments in extras
# - staff - all staff
# 

sub getSubset( $ ) {
    my $self = shift;
    my $subset = shift;

    #-- all is just all students
    if ( $subset eq "all" ) {
        return $self->{BY_ROLE}->[0];
    } elsif ( $subset eq "staff" ) {
        return $self->{BY_ROLE}->[1];
    } elsif ( $subset eq "Online" || $subset eq "Toowoomba" ||
              $subset eq "Springfield" || $subset eq "Fraser Coast" ) {
        my @data = grep { $_->{EXTRAS}->{mode} eq $subset }
                         @{$self->{BY_ROLE}->[0]};

        return \@data;
    }
    return undef;
}

#-----------------------------------------------------------------
# getSubsetQuantityStats( $subset )
# - given an array of entries (subset)
# - for the subset

sub getSubsetQuantStats() {
    my $self = shift;
    my $subset = shift;

    my $stats = Statistics::Descriptive::Full->new();
    $stats->add_data( map { $_->{quantity} } @$subset );

    return $stats;
}


1;


