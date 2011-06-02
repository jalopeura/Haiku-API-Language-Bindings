package Perl::Generator;
use Perl::ClassGenerator;
use Perl::MainClassGenerator;
use Perl::UtilityHWriter;
use Perl::UtilityCPPWriter;
use Perl::Types;
use strict;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
}

# called when the initial file is loaded; not called for included files
# for perl, we create an initial XS file, which does the following:
#    includes all the necessary H files for all the classes
#    includes subsequent XS files
#    defines a tied hash class
#    defines a make_perl_object class
sub start_processing {
	my ($self, $infile, $outfolder) = @_;
	($self->{package}) = $infile=~m:([^/]+)\.def$:g;
	
	$self->{master_include} = "$self->{package}.h";
	
	mkdir "$outfolder/perl" unless -e "$outfolder/perl";
	
	$self->{folder} =  "$outfolder/perl/$self->{package}";
	mkdir $self->{folder} unless -e $self->{folder};
	
	# clear out members in case we're doing multiples
	$self->{types} = new Perl::Types;
	
	$self->{classes} = [];
	$self->{include} = [];
}

# called when the initial file has been fully parsed; not called for imported files
# for perl, we generate our initial XS file
sub end_processing {
	my ($self, $infile, $outfolder) = @_;
	$self->write;
}

# a bundle is a convenience label for a group of classes that will be loaded together
sub bundle {
	my ($self, $bundle) = @_;
	$self->{bundle} = $bundle;
	
	my $class = $self->add_class(target => $bundle);
	$self->{current_class} ||= $class;
	
	$self->{current_class}->module($bundle);
	
}

# called when the binding needs to include other files
sub include {
	my ($self, @files) = @_;
	$self->{include} ||= [];
	NEW: for my $new (@files) {
		for my $existing (@{ $self->{include} }) {
			next NEW if $new eq $existing;
		}
		push @{ $self->{include} }, $new;
	}
}

# called when the binding needs to link to libraries
sub linklib {
	my ($self, @files) = @_;
	$self->{include} ||= [];
	NEW: for my $new (@files) {
		for my $existing (@{ $self->{linklib} }) {
			next NEW if $new eq $existing;
		}
		push @{ $self->{linklib} }, $new;
	}
}

sub add_class {
	my ($self, %def) = @_;
	my $name = $def{target};
	$self->{classes} ||= [];
	
	my $class;
	for my $c (@{ $self->{classes} }) {
		next unless $c->name eq $name;
		$class = $c;
		last;
	}
	
	unless ($class) {
		$def{generator} = $self;
		if ($name eq $self->{bundle}) {
			$class = new Perl::MainClassGenerator($self->{folder}, \%def);
		}
		else {
			$class = new Perl::ClassGenerator($self->{folder}, \%def);
		}
		push @{ $self->{classes} }, $class;
	}
	
	return $class;
}

# called when a new bound class is started
sub start_class {
	my ($self, %def) = @_;
	
	my $class = $self->add_class(%def);
	
	$class->module($self->{bundle});
	$self->{current_class} = $class;
}

# called when a bound class has been completely parsed
sub end_class {
	my ($self) = @_;
	my $class = delete $self->{current_class};
	$class->write unless $class->isa('Perl::MainClassGenerator');
}

sub property {
	my ($self, %property) = @_;
	$self->{current_class}->property(\%property);
}

sub constant {
	my ($self, %constant) = @_;
	$self->{current_class}->constant(\%constant);
}

sub type {
	my ($self, %type) = @_;
	$self->{types}->register_type($type{name}, $type{builtin}, $type{target});
}

sub constructor {
	my ($self, $def, @params) = @_;
	$self->{current_class}->constructor($def, @params);
}

sub destructor {
	my ($self) = @_;
	$self->{current_class}->destructor();
}

sub method {
	my ($self, $def, $return, @params) = @_;
	$def->{target} ||= $def->{cpp};	# if no target name specified, use cpp name
	$self->{current_class}->method($def, $return, @params);
}

sub event {
	my ($self, $def, $return, @params) = @_;
	$def->{target} ||= $def->{cpp};	# if no target name specified, use cpp name
	$self->{current_class}->event($def, $return, @params);
}

sub class_map {
	my ($self) = @_;
	my @ret;
	if ($self->{classes}) {
		for my $class (@{ $self->{classes} }) {
			push @ret, $class->class_map;
		}
	}
	return @ret;
}

sub write {
	my ($self) = @_;
	
	# get the class map and register the responder object types
	my @class_map = $self->class_map;
	for my $map (@class_map) {
		my $builtin = $map->[2] ? 'responder_ptr' : 'object_ptr';
		$self->{types}->register_type($map->[0] . '*', $builtin);
	}
	
	unless (-e $self->{folder}) {
		my @path = split /::/, $self->{folder};
		for my $i (0..$#path) {
			my $p = join('/', @path[0..$i]);
			next if -e $p;
			mkdir $p;
		}
	}
	
	# set up some needed variables
	my ($main_class, @c_files, @h_files, @o_files);
	if ($self->{classes}) {
		for my $class (@{ $self->{classes} }) {
			if ($class->isa('Perl::MainClassGenerator')) {
				$main_class = $class;
			}
			next unless $class->{events};
			push @c_files, $class->{responder_cpp_filename};
			push @h_files, $class->{responder_h_filename};
			
			my ($o_file) = $class->{responder_h_filename}=~m:([^/]+)$:;
			#my $o_file = $class->{responder_h_filename};
			$o_file=~s/\.h$/\$(OBJ_EXT)/;
			push @o_files, $o_file;
		}
	}
	my $name = $main_class->name();
	my $version = $main_class->version;
	my ($basename) = $name=~/([^:]+)$/;
	
	# utility functions (H and CPP files)
	$self->write_utility_h_file();
	$self->write_utility_cpp_file();

	# for convenience, make a master include file
	my $hfilename = "$self->{folder}/$self->{master_include}";
	open OUT, ">$hfilename" or die "Unable to create file '$hfilename': $!";
	print OUT <<INTRO;
/*
 * Automatically generated file
 */

#ifndef _BINDING_MASTER
#define _BINDING_MASTER

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

INTRO
	
	if ($self->{include}) {
		for my $file (@{ $self->{include} }) {
			print OUT qq(#include <$file>\n);
		}
		print OUT "\n";
	}
	
	# do local includes
	if (@class_map) {
		for my $map (@class_map) {
			next unless $map->[2];	# true value indicates responder class
			(my $file = $map->[1])=~s!::!_!g;
			print OUT qq(#include "$file.h"\n);
		}
		print OUT "\n";
	}
	
	print OUT <<END;
#include "${basename}Utils.h"

#endif	// _BINDING_MASTER
END
	
	close OUT;
	
	# the XS and PM files are written by the MainClassGenerator file
	$main_class->write;
	
	# make a typemap file
	$self->{types}->write_typemap_file("$self->{folder}/typemap");
	
	# now write Makefile.PL
	my $c_files = join(', ', "'$basename.c'", "'${basename}Utils.cpp'", map { s:^$self->{folder}/::; "'$_'" } @c_files);
	my $h_files = join(', ', "'${basename}Utils.h'", map { s:^$self->{folder}/::; "'$_'" } @h_files);
	my $o_files = join(' ', "$basename\$(OBJ_EXT)", "${basename}Utils\$(OBJ_EXT)", @o_files);

'$(BASEEXT)$(OBJ_EXT)', 

	my $libs = join(' ', map { "$_.\$(DLEXT)" } @{ $self->{linklib} });
#'LIBS' => ["-ltcl", "-ltk", "-lX11"]
#See ODBM_File/Makefile.PL for an example
	my $name = $main_class->name();
	my $version = $main_class->version;
	
	# Makefile.PL
	open MPL, ">$self->{folder}/Makefile.PL" or die "Unable to create Makefile.PL: $!";
	print MPL <<MAKE;
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'     => '$name',
	'VERSION'  => '$version',
	'CC'       => 'g++',
	'LD'       => '\$(CC)',
	'XSOPT'    => '-C++',
	'XS'       => { '$basename.xs' => '$basename.c' },
	'C'        => [$c_files],
	'H'        => [$h_files],
	'OBJECT'   => '$o_files',
	'BSLOADLIBS' => '$libs',
);
MAKE
	
	# a loading test
	unless (-e "$self->{folder}/t") {
		mkdir "$self->{folder}/t";
	}
	open TEST, ">$self->{folder}/t/load.t" or die "Unable to create test: $!";
	print TEST <<OUT;
use Test::Simple tests => 1;

use $name;

ok(1);
OUT
	
}

1;

__END__


# for each class described
# create an XS file; this should include whatever files are necessary
# if there are events, create an H file and a CPP file with a new responder class
#    as well as an XS file for this responder class

# so our main file needs to make a tied hash class
# we then tie a hash to that class, make a ref of that hash, bless that ref
# and voila
