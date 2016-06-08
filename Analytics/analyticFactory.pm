#
# FILE:     analyticFactory.pm
# PURPOSE:  
#      my $factory = QILTers::Analytics::analyticFactory->new();
#      my $model = $factory->getModel( OFFERING => ANALYTIC => )
#      my $view = $factory->getView( $model );
#
#

use strict;

package analyticFactory;

use CGI;

sub new
{
  my $debug = 0;
  print STDERR "\nDebugging analyticFactory\n1. shift" if ( $debug );

  my $proto = shift;
  my $class = ref( $proto ) || $proto;

  my $self = {};
  bless( $self, $class );

  print STDERR "\n2. new CGI (file uploads also happen here)" if ( $debug );

  # grab the query string
  # Any file uploads that are being done will happen here,
  # so this could take a while
  my $query = new CGI;

  #-- are we sending "text/html" or some other type of file
  my $header = $query->param( "header" );

  if ( $header eq "" )
  {
    print $query->header;
  }
  elsif ( $header ne "none" )
  {
    print $query->header( -type => $header );
  }

  print STDERR "\n3. path info" if ( $debug );

  #-- figure out which object and method we want
  my $info = $query->path_info();

  my $object = $info;
  $object =~ s#.*/object/([^/]*).*#$1#g;

  # strip out any .csv from the object name
  # as this is only used to get the browser to treat the output
  # as a .csv file
  $object =~ s#\.csv$##;
  $object =~ s#\.txt$##;

  print STDERR "\n4. require object" if ( $debug );

  #-- Create the object
  eval{ require "webfuse/lib/Objects/${object}.pm" } ;

  if ( $@ !~ /^$/ )
  {
    print "No object file: $@" ;
    return $self;
  }
  else
  {
    print STDERR "\n5. call object->new" if ( $debug );

    my $class = $object->new( $query );

    print STDERR "\n6. Done\n\n" if ( $debug );

    return $class;
  }
}

#--------------------------------------------------
# new_test( $object, $method )
# - constructor for when called locally

sub new_test
{
  my $proto = shift;
  my $class = ref( $proto ) || $proto;

  my $self = {};
  bless( $self, $class );

  my $object = shift || "WebfuseObject";

  eval{ require "${object}.pm" } ;

  if ( $@ !~ /^$/ )
  {
    #$self->{Error} = "No object file: $@" ;
    print "No object file: $@" ;
    return $self;
  }
  else
  {
    my $class = $object->new;
    return $class;
  }
}

#--------------------------------------------------

1;
