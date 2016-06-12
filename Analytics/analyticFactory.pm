#
# FILE:     analyticFactory.pm
# PURPOSE:  
#      my $factory = QILTers::Analytics::analyticFactory->new();
#      my $model = $factory->getModel( OFFERING => ANALYTIC => )
#      my $view = $factory->getView( $model );
#
#

package QILTers::Analytics::analyticFactory;

use strict;
use Data::Dumper;

my %ANALYTIC_TRANSLATE = (
    clickGrades => "clicks/grade",
    dhits => "content/forum %",
    dhitsGrades => "content/forum/grade",
    postsNetwork => "forum post network"
);

sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;

    my $self = {};
    bless( $self, $class );

    return $self;
}

#-----------------------------------------------------------------
# getModel( OFFERING => ANALYTIC => )
# - create and return an object of the appropriate type

sub getModel() {
    my $self = shift;
    my %args = @_;

    my $analytic = $args{ANALYTIC};
    #-- dhitsGrades uses the dhits model
    $analytic = "dhits" if ( $analytic eq "dhitsGrades" );

    #-- maybe do some smart work here eventually

    #-- Create the model and the view
    eval{ require "webfuse/lib/QILTers/Analytics/${analytic}.pm" } ;

    $analytic = "QILTers::Analytics::" . $analytic;

    if ( $@ !~ /^$/ ) {
        die "No object file for $analytic: $@" ;
    } else {
        my $class = $analytic->new( %args );

        return $class;
    }
}

#-----------------------------------------------------------------
# getView( MODEL => $model, COURSES => $offerings PATH => $path)
# - based on the model passed in create the view object, pass it $model
#   and return

sub getView( $) {
    my $self = shift;
    my %args = @_;

    my $model = $args{MODEL};
    my $offerings = $args{COURSES};
    my $path = $args{PATH};

    my $view = "QILTers::Analytics::" . $args{VIEW} . "_View";
    my $class_path = $view;
    $class_path =~ s#::#/#g ;
    #-- maybe do some smart work here eventually
    #-- Create the model and the view
    eval{ require "webfuse/lib/${class_path}.pm" } ;

    if ( $@ !~ /^$/ ) {
        die "No object file for $view: $@" ;
    } else {
        my $class = $view->new( MODEL => $model );

        $class->{PATH} = $path;
        $class->{COURSES} = $self->constructViewOfferings( $offerings, $path );

        return $class;
    }
}

#-----------------------------------------------------------------
# constructViewOfferings( \%OFFERINGS, $path )
# - construct the complex data structure required to generate the nested
#   menus in the view
# - Need to convert
#   my %COURSES = (
#       EDC3100 => {
#           "2015_1" => {
#               clickGrades => [ qw/ all / ]
#           },        "2015_2" => {
#               clickGrades => [ qw/ all / ]
#           }
#       },
#
# INTO
#  { 
#       LABEL => EDC3100, LINK => "URL or NULL"
#       OFFERINGS => [
#           { 
#               LABEL => "2015 S2", LINK => "URL" ||undef,
#               ANALYTICS => { 
#                   [ LABEL => "Click grades", LINK => "" ],
#                   [ LABEL => "Rossi", LINK => "" ],
#                   [ LABEL => "Paths", LINK => "" ] } ],
#               },
#           },
#           { 
#               LABEL => "EDS2401", LINK => undef, MENU => [] 
#           },
#           { 
#               LABEL => "EDX3270", LINK => undef, MENU => [] )
#           },
#       ]
#   }
#]

sub constructViewOfferings( $ ) {
    my $self = shift;
    my $offerings = shift;
    my $path = shift;

    my @viewOfferings;

    foreach my $course ( sort keys %$offerings) {
        #-- start constructing the element
        my $element = { LABEL => $course };

        #-- hold all information about the offerings for a course
        my @courseOfferings;
        #-- loop through each of the offerings
        foreach my $offering ( keys %{$offerings->{$course}} ) {
            my $numAnalytics = keys %{$offerings->{$course}->{$offering}};

            #-- if there are analytics then do those, otherwise
            #   set it up as zero

            #-- array to hold all the analytics information
            my $offeringAnalytic;
            my @offeringAnalytics; 

            if ( $numAnalytics > 0 ) {
                #-- give a link to the top level course menu
                $element->{LINK} = ".";

                #-- set up label for the course offering
                $offeringAnalytic = { LABEL => $offering, LINK => "." };
                
                #-- loop through each of the analytics and add array entries
                #   for each and add something to $offeringAnalytic->{ANALYTICS}
                my @analytics;
                foreach my $analytic ( 
                        keys %{$offerings->{$course}->{$offering}} ) {

                    my $subset = $offerings->{$course}->{$offering}->{$analytic}->[0] . ".html";

                    $subset = "index.html" if ( $subset eq "all.html" );

                    if ( ! exists $ANALYTIC_TRANSLATE{$analytic} ) {
                        die "Can't find translation for $analytic\n";
                    }
                    push @analytics, {
                        LABEL => $ANALYTIC_TRANSLATE{$analytic},
                        LINK => "$path/$course/$offering/$analytic/$subset"
                    };
                }
                $offeringAnalytic->{ANALYTICS} = \@analytics;

                push @{$element->{OFFERINGS}}, $offeringAnalytic;
            }

        }
        push @viewOfferings, $element;
    }
#print Dumper( \@viewOfferings );
    return \@viewOfferings;
#        #-- get the components of the offering
#        my @offerings = split /_/, $offerings{$offering};
#        my $course = $0; my $year = $1; my $term = $2;

         
}


1;
