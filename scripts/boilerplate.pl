#!/usr/bin/perl

use v5.36;
use feature qw(signatures);
no feature qw(indirect);
use utf8;

# Author          : Johan Vromans
# Created On      : Thu Jan 25 19:14:38 2024
# Last Modified By: 
# Last Modified On: Thu Jan 25 22:30:37 2024
# Update Count    : 54
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( gen 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $select;
my $prefix;
my $outfile;
my $verbose = 1;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';
binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' );

################ The Process ################

use File::LoadLines qw(loadblob);
use JSON::PP;

my $json = JSON::PP->new->utf8->relaxed;

if ( $outfile ) {
    open( STDOUT, '>:utf8', $outfile ) ||die("$outfile: $!\n");
}

for my $file ( @ARGV ) {
    my $data = $json->decode( loadblob( $file ) );

    if ( $select ) {
	my $p;
	for ( split( ':', $select ) ) {
	    $p = $_;
	    $data = $data->{$p} or die("Select $select: No such element: $p\n");
	}
	$prefix //= ucfirst($p);
    }
    print( "# WARNING: This is generated boiler plate code. Please adjust.\n\n",
	   generate( $data, $prefix ) );
}
$prefix //= "Class";

################ Subroutines ################

sub generate( $data, $pfx ) {
    my $output = "class $pfx :does(Class::JSON_Object) {\n";
    my $children = "";

    # Length of excess field names.
    my $len = 3 + 3*8;
    for my $field ( keys %$data ) {
	$len = length($field) if length($field) > $len;
    }
    $len++;
    my $fmt = "%-${len}s\t%s";

    for my $field ( sort keys %$data ) {
	my $v = $data->{$field};

	# ARRAY.
	if ( ref($v) eq 'ARRAY' ) {
	    $v = $v->[0];
	    if ( ref($v) eq 'HASH' ) {
		my $pfx = $pfx . "_" . $field;
		$output .= "    field \@" .
		  sprintf( $fmt, $field, ":Class($pfx);\n" );
		$children .= generate( $v, $pfx );
	    }
	    else {
		$output .= "    field \@" .
		  sprintf($fmt, $field.";", "# \n" );
	    }
	}

	# HASH -> Object.
	elsif ( ref($v) eq 'HASH' ) {
	    my $pfx = $pfx . "_" . $field;
	    $output .= "    field \$" .
	      sprintf( $fmt, $field, ":Class($pfx);\n" );
	    $children .= generate( $v, $pfx );
	}

	# Scalar field.
	else {
	    $output .= "    field \$" .
	      sprintf( $fmt, $field.";", "# \n" );
	}
    }

    $output .= "}\n\n";
    return $children . $output;

}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( 'select=s'  => \$select,
		    'prefix=s'	=> \$prefix,
		    'output=s'	=> \$outfile,
		    'ident'	=> \$ident,
		    'verbose+'	=> \$verbose,
		    'quiet'	=> sub { $verbose = 0 },
		    'trace'	=> \$trace,
		    'help|?'	=> \$help,
		    'man'	=> \$man,
		    'debug'	=> \$debug )
	  or $pod2usage->( -exitval => 2, -verbose => 0 );
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->( -exitval => 0, -verbose => $man ? 2 : 0 );
    }
}

__END__

################ Documentation ################

=head1 NAME

boilerplate - generate boilerplate for Class::JSON_Object

=head1 SYNOPSIS

boilerplate [options] [file ...]

 Options:
   --select XX:YY	start with ->{XX}->{YY}
   --prefix XXX         Prefix for classes
   --output FILE        output file
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information
   --quiet		runs as silently as possible

=head1 OPTIONS

=over 8

=item B<--select=>I<XXX>

Instead of the top level object, start with top->{XXX}.

I<XXX> may be a series of objects separated by colons.

E.g., C<ResultObj:containers> will start generating at
top->{ResultObj}->{containers}.

=item B<--prefix=>I<XXX>

The prefix for the top level class. Child classes will have their name
appended, separated by an underscore.

E.g., if C<ResultObj:containers> has a field C<metadata> which is
another object, its class will become
C<ResultObj_containers_metadata>.

=item B<--output=>I<XXX>

Write the output to file I<XXX>. Default is to write to standard output.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.
This option may be repeated to increase verbosity.

=item B<--quiet>

Suppresses all non-essential information.

=item I<file>

The input file(s) to process. These must be valid JSON data files.

=back

=head1 DESCRIPTION

B<This program> will read the given input file and produce boiler
plate code for Class::JSON_Object classes.

=head1 EXAMPLE

Given a JSON data file with content:

    { "op" : {
          "control" : "process",
	  "data" : {
              "operation": "copy",
              "args": [ 47, 11 ]
          },
	  "result" : "OK"
    } }

This will produce the following boilerplate code (with C<--prefix=Op>):

    class Op_data :does(Class::JSON_Object) {
	field @args;                       	# 
	field $operation;                  	# 
    }

    class Op :does(Class::JSON_Object) {
	field $control;                    	# 
	field $data                        	:Class(Op_data);
	field $result;                     	# 
    }

=head1 SEE ALSO

This program is part of L<Class::JSON_Object>. See.

=cut

