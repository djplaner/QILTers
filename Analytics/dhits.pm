#
# FILE:		QILTers::Analytics::dhits.pm
# PURPOSE:	Model to map dhits (and various filters) for a given course
#
#   - same as clickGrades +
#   - TOTAL_DHITS provides access to totals and other stats for
#       STUDENTS
#       STAFF
#       ALL -- only totals available for these
#
#
# TO DO:	
#

package QILTers::Analytics::dhits;

$VERSION = '0.5';

use strict;

use Data::Dumper;
use Statistics::Descriptive;

use webfuse::lib::NewModel;
use webfuse::lib::QILTers::Analytics::clickGrades;

@QILTers::Analytics::dhits::ISA = ( "QILTers::Analytics::clickGrades" );

#--------------------
# Globals

use webfuse::lib::WebfuseConfig;
my $WEBFUSE_HOME=$WebfuseConfig::WEBFUSE_HOME;
my $DATA_DIR="$WebfuseConfig::WEBFUSE_DATA/databases";
my $CONFIG = "$DATA_DIR/StudyDesk2015.txt";

#- specify which quantity type of interest
#my $Q_TYPE = "USER DHITS";

# CONDITIONS is constructed in handle_params based on parameters
# passed in

#my $QILT_Q_DEFAULTS = {
#    TABLE => "qilt_quantities",
#    FIELDS => "userid,roleid,course,term,year,q_type,quantity",
#    CONDITIONS => "course={course} and term={term} and year={year} and " .
#                  "q_type={q_type}"
#};

#my $EXTRAS_DEFAULTS = {
#    TABLE => "mdl_user_extras",
#    FIELDS => "userid,course,term,year,mark,grade,gpa,program,plan,birthdate,mode,postal_code,completed_units,transferred_units,acad_load",
#    CONDITIONS => "course={course} and term={term} and year={year}"
#};

my @REQUIRED_PARAMETERS = ( qw/ OFFERING course term year q_type / );


#-------------------------------------------------------------
# new(  )

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    
    my %args = @_;

    $args{q_type} = "USER DHITS";
    bless( $self, $class );

    $self = $self->SUPER::new( %args );

    $self->addUserExtras();
    $self->setUpRoleData();

    $self->createTotalDhits();

    return $self;
}

#-------------------------------------------------------------
# getClickGrades()
# - return a clickGrades object with the same offering
# - used by all content / forum clicks analytic

sub getClickGrades() {
    my $self = shift;

    $self->{CLICK_GRADES} = QILTers::Analytics::clickGrades->new( 
                                OFFERING => $self->{KEYS}->{OFFERING} );

    if ( $self->{CLICK_GRADES}->Errors() ) {
        $self->{CLICK_GRADES}->DumpErrors();
        die;
    }
}

1;


