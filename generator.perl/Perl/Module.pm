package Perl::Module;
use File::Spec;
use File::Path;
use Perl::Package;
use Perl::ResponderPackage;
use Perl::Types;
require Perl::UtilityCodeGenerator;
use strict;
our @ISA = qw(Perl::Package);

sub new {
	my ($class, $bindings) = @_;
	
	my $self = bless {
		packages => [],
		version => $bindings->{version},
	}, $class;
	
	# need to create this now, in order to pass it to packages
	my $types = new Perl::Types;
	
	for my $binding ($bindings->bindings) {
		my $package = new Perl::Package($self, $binding, $types);
		
		if ($binding->target eq $bindings->name) {
			# copy package into self
			my @keys = keys %$package;
			@{$self}{@keys} = @{$package}{@keys};
		}
		else {
			push @{ $self->{packages} }, $package;
		}
		
		if ($binding->events) {
			push @{ $self->{packages} }, new Perl::ResponderPackage($self, $binding, $types);
		}
	}
	
	# register defined types
	for my $btypes ($bindings->types_collection) {
		for my $type ($btypes->types) {
			$types->register_type(
				$type->name,
				$type->builtin,
				$type->target,
			);
		}
	}
	
	# register the types we've just created
	for my $package (@{ $self->{packages} }) {
		if (my $cpp_class = $package->{cpp_class}) {
			$types->register_type(
				"$cpp_class*",
				$package->{type},
				$package->{name},
			);
		}
	}
	
	if (my @includes = $bindings->includes_collection) {
		my @inc;
		for my $includes (@includes) {
			for my $include ($includes->includes) {
				push @inc, $include->file;
			}
		}
		$self->{includes} = \@inc;
	}
	
	
	# if we had no binding named the same as ourself we need to do some more
	unless ($self->{name}) {
		$self->{types} ||= $types;
	}
	
	$self->{isa} ||= [];
	unshift @{ $self->{isa} }, 'DynaLoader';
	$self->{dynaloader} = 1;
	
	return $self;
}

sub open_files {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	my @subpath = split /::/, $self->{name};
	my $filename = pop @subpath;
	
	mkpath($folder);
	
	# PM file
	my $pm_filename = File::Spec->catfile($folder, "$filename.pm");
	open $self->{pmh}, ">$pm_filename" or die "Unable to create file '$pm_filename': $!";
	
	# XS file
	my $xs_filename = File::Spec->catfile($folder, "$filename.xs");
	open $self->{xsh}, ">$xs_filename" or die "Unable to create file '$xs_filename': $!";
	
	$self->{filename} = $filename;
}

sub close_files {
	my ($self) = @_;
	close $self->{pmh};
	close $self->{xsh};
}

sub generate {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	# generate packages before self, so packages can report filenames
	for my $package (@{ $self->{packages} }) {
		$package->generate($folder, $pm_prefix, $xs_prefix);
	}
	
	$self->SUPER::generate($folder, $pm_prefix, $xs_prefix);
	
	# create the typemap
	if ($self->{types}->registered_type_count) {
		my $typemap_file = File::Spec->catfile($folder, 'typemap');
		$self->{types}->write_typemap_file($typemap_file);
	}
	
	
	# no name member means we had no binding named the same as ourself
	# this means we're just being used to bundle other modules
	# so no utility files are necessary
	if ($self->{name}) {
		$self->generate_utility_h_code($folder);
		$self->generate_utility_cpp_code($folder);
	}
}

#
# overridden code-generation functions
#

sub generate_xs_preamble {
	my ($self) = @_;
	
	my $perl_module_name = $self->{name};
	
	print { $self->{xsh} } <<TOP;
/*
 * Automatically generated file
 */
 
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "$self->{filename}.cpp"
TOP
	
	# determine CPP and XS includes
	my (@cpp_includes, @xs_includes);	
	for my $package (@{ $self->{packages} }) {
		push @xs_includes, $package->{xs_include};
		next unless $package->isa('Perl::ResponderPackage');
		
		push @cpp_includes, $package->{cpp_include};
	}
	
	if (@cpp_includes) {
		for my $file (@cpp_includes) {
			print { $self->{xsh} } qq(#include "$file"\n);
		}
		print { $self->{xsh} } "\n";
	}
		
	print { $self->{xsh} } <<MODINFO;
MODULE = $perl_module_name	PACKAGE = $perl_module_name

MODINFO
	
	if (@xs_includes) {		
		for my $file (@xs_includes) {			
			print { $self->{xsh} } qq(INCLUDE: $file\n);
		}
		
		print { $self->{xsh} } <<MODINFO;

# since the XS included above probably changed it, force correct module
MODULE = $perl_module_name	PACKAGE = $perl_module_name

MODINFO
	}
}

sub generate_pm_postamble {
	my ($self) = @_;
	
	my $perl_module_name = $self->{module}{name};
	
	print { $self->{pmh} } <<END;
bootstrap $perl_module_name \$VERSION;

1;
END
}

sub generate_xs_postamble {
	my ($self) = @_;
	
	my $perl_module_name = $self->{module}{name};
	
	print { $self->{xsh} } <<DBG;
MODULE = $perl_module_name	PACKAGE = ${perl_module_name}::DEBUG

SV*
FETCH(tie_obj)
		SV* tie_obj;
	CODE:
		RETVAL = newSViv(debug_level);
	OUTPUT:
		RETVAL

void
STORE(tie_obj, value)
		SV* tie_obj;
		SV* value;
	CODE:
		debug_level = SvIV(value);
		
MODULE = $perl_module_name	PACKAGE = $perl_module_name

BOOT:
	set_up_debug_sv("${perl_module_name}::DEBUG");
DBG
}

1;
