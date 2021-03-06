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
            clickGrades => [ qw/ all Online Springfield Toowoomba Fraser_Coast / ],
            dhits => [ qw/ all Online Springfield Toowoomba Fraser_Coast staff / ],
            dhitsGrades => [ qw/ all Online Springfield Toowoomba Fraser_Coast staff / ],
            postsNetwork => [ qw/ all 49765 49752/ ]
        
        },
        "2015_2" => {
            clickGrades => [ qw/ all  / ],
            dhits => [ qw/ all staff  / ],
            dhitsGrades => [ qw/ all staff  / ],
            postsNetwork => [ qw/ all / ]
        }
    },
    EDS4250 => {
        "2015_1" => {
            clickGrades => [ qw/ all / ],
            dhits => [ qw/ all staff / ],
            dhitsGrades => [ qw/ all staff  / ],
            postsNetwork => [ qw/ all / ]
        },
        "2015_2" => {
            clickGrades => [ qw/ all Online Toowoomba/ ],
            dhits => [ qw/ all staff Online Toowoomba/ ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff Online Toowoomba/ ]
        },
    },
    #-- the empty ones for now
    EDS2401 => {
        "2015_1" => {
            clickGrades => [ qw/ all Fraser_Coast Online Springfield Toowoomba / ],
            dhits => [ qw/ all staff Fraser_Coast Online Springfield Toowoomba / ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff Fraser_Coast Online Springfield Toowoomba / ]
        },
        "2015_2" => {
            clickGrades => [ qw/ all / ],
            dhits => [ qw/ all staff / ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff / ]
        },
    },    
    EDX3270 => {
        "2015_1" => {
            clickGrades => [ qw/ all Fraser_Coast ONline Springfield Toowoomba / ],
            dhits => [ qw/ all staff Fraser_Coast ONline Springfield Toowoomba/ ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff Fraser_Coast ONline Springfield Toowoomba/ ],
        },
        "2015_2" => {
            clickGrades => [ qw/ all / ],
            dhits => [ qw/ all staff / ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff / ],
        },
    },
    EDX3160 => {
        "2015_2" => {
            clickGrades => [ qw/ all Fraser_Coast Online Springfield Toowoomba / ],
            postsNetwork => [ qw/ all / ],
            dhits => [ qw/ all staff Fraser_Coast Online Springfield Toowoomba / ],
            dhitsGrades => [ qw/ all staff Fraser_Coast Online Springfield Toowoomba / ],
        },
    },
    EDC4000 => {
        "2015_1" => {
            clickGrades => [ qw/ all Online Springfield Toowoomba / ],
            dhits => [ qw/ all staff Online Springfield Toowoomba / ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff Online Springfield Toowoomba / ],
        },
        "2015_2" => {
            clickGrades => [ qw/ all Online Springfield Toowoomba / ],
            dhits => [ qw/ all staff Online Springfield Toowoomba / ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff Online Springfield Toowoomba / ],
        },
    },
    EDC1400 => {
        "2015_1" => {
            clickGrades => [ qw/ all Fraser_Coast Online Springfield Toowoomba / ],
            postsNetwork => [ qw/ all / ],
            dhits => [ qw/ all staff  Online Springfield Toowoomba / ],
            dhitsGrades => [ qw/ all staff  Online Springfield Toowoomba / ],
        },
        "2015_2" => {
            clickGrades => [ qw/ all  Online Springfield Toowoomba / ],
            dhits => [ qw/ all staff  Online Springfield Toowoomba / ],
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff  Online Springfield Toowoomba / ],
        },
    },
    EDP4130 => {
        "2015_1" => {
            dhits => [ qw/ all staff Fraser_Coast Online Springfield Toowoomba/ ] ,
            postsNetwork => [ qw/ all / ],
            dhitsGrades => [ qw/ all staff Fraser_Coast Online Springfield Toowoomba/ ] ,
            clickGrades => [ qw/ all Fraser_Coast Online Springfield Toowoomba/ ] 
        }
    },
); 

my $DOCUMENT_ROOT = "/Applications/mappstack-5.4.36-0/apache2/htdocs/qilters";
my $PATH = "/qilters";

my $factory = QILTers::Analytics::analyticFactory->new();

foreach my $course ( keys %COURSES ) {
print "COURSE is $course\n";
    foreach my $offering ( keys %{$COURSES{$course}} ) {
print "** OFfering is $offering\n";
        foreach my $analytic ( keys %{$COURSES{$course}->{$offering}} ) {
print "**** analytics is $analytic\n";
            foreach my $subset ( @{$COURSES{$course}->{$offering}->{$analytic}} ) {
print "****** SUBSET is $subset\n";
                $subset =~ s/_/ /g;

                my $model = $factory->getModel( 
                                OFFERING => "${course}_$offering",
                                ANALYTIC => $analytic );
#print "MOdel is " . ref( $model ) . "\n";
#print Dumper( $model->{DATA} );
                #-- might need to provide "template" file of other information here
                my $view = $factory->getView( MODEL => $model, 
                        VIEW => $analytic,
                        COURSES => \%COURSES, PATH => $PATH );
print "          VIEW is " . ref( $view ) . "\n";
                my $string = $view->Display( SUBSET => $subset,
                            COURSE => $course, OFFERING => $offering,
                                ANALYTIC => $analytic,
                                         COURSES => \%COURSES );
#print $string;
#die;
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

                                        
