#
# FILE:     fixPlan.pl
# PURPOSE:  Look at the plan field in mdl_user_extras and clean the data
#
#   - loop through each entry
#   - test and translate it against a translation field
#   - crash if there's no match in translation

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
    CONDITIONS => "course={course} and term={term} and year={year}"
};

#-- use a comma to separate multiples
my %PLAN_FILTER = (  
    "Unspecified" => "Unspecified",
    "Primary" => "Primary",
    "Secondary" => "Secondary",
    "SpecEduc" => "SpecEduc",
    "EarlyChild" => "EarlyChild",

    #-- SHPE
    "* Sport, Health & PE+Secondary" => "SHPE,Secondary",
    "Sport, Health & PE+Secondary" => "SHPE,Secondary",
    "Secondary+Health & PE" => "SHPE,Secondary",
    "Secondary+Health & PE+SpecEdu" => "SHPE,SpecEduc",
    "* Sport, Health & PE+Primary" => "SHPE,Primary",
    "Sport, Health & PE+Primary" => "SHPE,Primary",
    "Health & PE+Primary" => "SHPE,Primary",
    "* Secondary+PhysEduc+Bio" => "SHPE,Secondary,Bio",
    "Secondary+Health & PE+ModHisto" => "SHPE,Secondary,ModHis",
    "Secondary+Health & PE+English" => "SHPE,Secondary,English",

    "Secondary+English+SpecEdu" => "Secondary,English,SpecEduc",
    "Secondary+ModHistory+English" => "Secondary,English,ModHistory",

    "* Secondary+Bio" => "Secondary,Bio",

    "Secondary+InfoTechSys" => "Secondary,InfoTechSys",
    "* Secondary+VocationalEdu" => "Secondary,VocationalEdu",
    "Secondary,English" => "Secondary,English",
    "Secondary+Maths+Physics" => "Secondary,Maths,Physics",
    "* Secdary+BusOrgMgt+SpecEduc" => "Secondary,BusOrgMgt,SpecEduc",
    "* Secondary+EngComm+History" => "Secondary,EngComm,History",
    "Secondary+AgSci" => "Secondary,AgSci",
    "Secondary+Music+AgSci" => "Secondary,AgSci,Music",
    "Secondary+SpecEduc" => "Secondary,SpecEduc",
    "Secondary+AncientHis" => "Secondary,AncientHis",
    "Secondary+Maths+Music" => "Secondary,Maths,Music",
    "Secondary+ModHistory+Geography" => "Secondary,ModHis,Geography",
    "Secondary+VisArts+English" => "Secondary,VisArts,English",
    "Secondary+English+ModHistory" => "Secondary,English,ModHis",
    "Secondary+English+AncientHist" => "Secondary,English,AncientHis",
    "Secondary+EngTech" => "Secondary,EngTech",
    "* Secondary+IndTechDes" => "Secondary,IndTechDes",
    "* Secondary+Bio+Maths" => "Secondary,Bio,Maths",
    "Secondary+AncientHist+English" => "Secondary,AncientHis,English",
    "Secondary+Health & PE+BioSci" => "Secondary,SHPE,Bio",
    "Secondary+Graphics+InfoTechSys" => "Secondary,Graphics,InfoTechSys",
    "Secondary+Graphics+DesgnTech" => "Secondary,Graphics,IndTechDes",
    "Secondary+DesgnTech" => "Secondary,IndTechDes",
    "Secondary+Drama+Maths" => "Secondary,Drama,Maths",
    "Secondary+Health & PE+Maths" => "SHPE,Secondary,Maths",
    "Secondary+AncientHist+BioSci" => "Secondary,AncientHis,Bio",
    "Secondary+InfoTechSys+LegalStu" => "Secondary,InfoTechSys,LegalStud",
    "Secondary+ModHistory+LegalStud" => "Secondary,ModHis,LegalStud",
    "Secondary+English+Geography" => "Secondary,English,Geography",
    "Secondary+English+BusComTech" => "Secondary,English,BusComTech",
    "Secondary+Physics+StudRelign" => "Secondary,Physics,StudRelign",
    "* Secondary+MusCraftHis" => "Secondary,MusCraftHis",
    "Secondary+Chemistry+Maths" => "Secondary,Chemistry,Maths",
    "Secondary+Health & PE+AncientH" => "Secondary,SHPE,AncientHis",
    "* Secondary+VisArts" => "Secondary,VisArts",
    "Secondary+Maths+SpecEd" => "Secondary,Maths,SpecEduc",
    "Secondary+Health & PE+Music" => "Secondary,SHPE,Music",
    "* Secondary+CompIPT" => "Secondary,CompIPT",
    "* Secondary+EngComm+PhysEduc" => "Secondary,EngComm,SHPE",
    "* Secondary+EngComm" => "Secondary,EngComm",
    "* Secondary+PhysEduc" => "Secondary,SHPE",
    "* Secondary+AncntHist+BusOrgMg" => "Secondary,AncientHis,BusOrgMgt"
 );

my @OFFERINGS = ( qw/ EDC3100_2015_1 EDC3100_2015_2 / );

my %CORRECT_VALUES = map { ( $_ => 1 ) } values %PLAN_FILTER;

foreach my $offering ( @OFFERINGS ) {
    my @offering = split /_/, $offering;

    my $extras = NewModel->new( CONFIG => $CONFIG,
                DEFAULTS => $NEW_EXTRAS_DEFAULTS,
                KEYS => { course => $offering[0], term => $offering[2],
                          year => $offering[1] } );

    if ( $extras->Errors() ) {
        $extras->DumpErrors();     
        die;
    }

    my @changes;
    #-- loop through and check/change the plan
    foreach my $student ( @{$extras->{DATA}} ) {
        #-- does the student's plan even exist
        if ( ! exists $PLAN_FILTER{ $student->{plan} } ) {
            print Dumper( $student );
            print "No filter plan for $student->{plan}\n";
            die;

        #-- is the student's plan a correct value, skip onto next one
        } elsif ( exists $CORRECT_VALUES{$student->{plan}} ) {
            next;

        #-- is there a mismatch 
        } elsif ( $PLAN_FILTER{$student->{plan}} ne $student->{plan} ) {
            $student->{plan} = $PLAN_FILTER{$student->{plan}};
            push @changes, $student;        
        }
    }

    my $change = @changes;

    if ( $change > 0 ) {
        print Dumper( \@changes );
    }
}
