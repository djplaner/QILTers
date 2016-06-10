#
# FILE:     buildSite.pl
# PURPOSE:  Construct the website for all the courses
# - Given an array of offerings specifying which analytics for each offering
#   and the modes for each analytic
# - Loop through and construct the course site
# - DOCUMENT_ROOT/COURSE/YEAR_TERM/ANALYTIC/subset.html

BEGIN {
  push @INC, "/Library/Perl/5.8.1";
}

use strict;
use File::Path qw( make_path );
use Data::Dumper;

use webfuse::lib::QILTers::Analytics::analyticFactory;

# The "names" for analytics in offerings should correspond to the names
# of the classes

my %COURSES = (
    EDC3100 => {
        "2015_1" => {
            clickGrades => [ qw/ all Online Springfield Toowoomba Fraser_Coast / ]
        },
        "2015_2" => {
            clickGrades => [ qw/ all  / ]
        }
    },

    #-- the empty ones for now
    EDS2401 => {
        "2015_1" => {}
    },    
    EDX3270 => {
        "2015_1" => {}
    },
    EDX3160 => {
        "2015_1" => {}
    },
    EDC4000 => {
        "2015_1" => {}
    },
    EDC1400 => {
        "2015_1" => {}
    },
    EDP4130 => {
        "2015_1" => {}
    },
    EDE4010 => {
        "2015_1" => {}
    }
);

my $DOCUMENT_ROOT = "/Applications/mappstack-5.4.36-0/apache2/htdocs/qilters";
my $PATH = "/qilters";

my $factory = QILTers::Analytics::analyticFactory->new();

foreach my $course ( keys %COURSES ) {
    foreach my $offering ( keys %{$COURSES{$course}} ) {
print "******** OFfering is $offering\n";
        foreach my $analytic ( keys %{$COURSES{$course}->{$offering}} ) {
            foreach my $subset ( @{$COURSES{$course}->{$offering}->{$analytic}} ) {

print "SUBSET is $subset\n";
                $subset =~ s/_/ /g;

                my $model = $factory->getModel( 
                                OFFERING => "${course}_$offering",
                                ANALYTIC => $analytic );

                #-- might need to provide "template" file of other information here
                my $view = $factory->getView( MODEL => $model, 
                        COURSES => \%COURSES, PATH => $PATH );
                my $string = $view->Display( SUBSET => $subset,
                            COURSE => $course, OFFERING => $offering,
                                         COURSES => \%COURSES );

                $subset =~ s/ /_/g;
                writePage( OFFERING => "${course}_$offering", 
                        ANALYTIC => $analytic, SUBSET => $subset, 
                        STRING => $string );
            }
        }
    }
}

#------------------------------------------------------------------ 
# writePage
# - write the HTML page

sub writePage( ) {
    my %args = @_;

    my @offering = split /_/, $args{OFFERING};

    #-- if SUBSET is "all" then convert to index.html so that there's
    #   a web page for the menu
    $args{SUBSET} = "index" if ( $args{SUBSET} eq "all" ) ;

    my $dir = "$DOCUMENT_ROOT/$offering[0]/$offering[1]_$offering[2]/$args{ANALYTIC}";
    make_path( $dir );

    my $filename = "$DOCUMENT_ROOT/$offering[0]/$offering[1]_$offering[2]/$args{ANALYTIC}/$args{SUBSET}.html";

    if ( open( my $fh, ">", $filename ) ) {
        print $fh $args{STRING};
        close $fh;
    } else {
        die "Unable to write to $filename\n";
    }
}

                                        
