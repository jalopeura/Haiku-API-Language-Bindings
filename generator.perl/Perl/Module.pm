package Perl::Module;
use File::Spec;
use File::Path;
use Perl::Bundle;
use Perl::Package;
use Perl::ResponderPackage;
use Perl::Include;
use Perl::Link;
use Perl::Types;
require Perl::UtilityCodeGenerator;
use strict;
our @ISA = qw(Bindings Perl::Package);

sub new {
	my ($class, $bindings) = @_;
	my $self = $class->upgrade($bindings->source_type_prefix, $bindings);
	
	if ($self->has('packages')) {
		my @pkgs = $self->packages;
		$self->{packages} = [];
		for my $package (@pkgs) {
			if ($package->perl_name eq $self->name) {
				# copy self into package and rebless package as self
				# we MUST do this before anybody else has a reference
				# to self, that's why we do it at the top of new()
				my @keys = keys %$self;
				@{$package}{@keys} = @{$self}{@keys};
				$self = bless $package, ref $self;
				
				# we are a dynaloader
				$self->{_isa} ||= [];
				unshift @{ $self->{_isa} }, 'DynaLoader';
			}
			else {
				push @{ $self->{packages} }, $package;
			}
			
			if ($package->has('functions') and $package->functions->had('events')) {
				push @{ $self->{packages} },
					Perl::ResponderPackage->upgrade($bindings->source_type_prefix, $package);
			}
		}
	}
	
	$self->propagate_value('module_name', $self->name);
	
	$self->{types} ||= Perl::Types->create_empty;
	$self->propagate_value('types', $self->types);
	
	if ($self->has('packages')) {
		for my $package ($self->packages) {
			if ($package->has('cpp_name')) {
				my $name = $package->cpp_name;
				my $type = $package->is_responder ? 'responder' : 'object';
				my $target = $package->perl_name;
				$self->types->register_type($name, $type, $target);
				
				$name .= '*'; $type .= '_ptr';
				$self->types->register_type($name, $type, $target);
			}
		}
	}
	
	return $self;
}

sub generate {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	# generate packages before self, so packages can report filenames
	if ($self->has('packages')) {
		for my $package ($self->packages) {
			$package->generate($folder, $pm_prefix, $xs_prefix);
		}
	}
	
	$self->SUPER::generate($folder, $pm_prefix, $xs_prefix);
	
	# create the typemap
	if ($self->types->registered_type_count) {
		my $typemap_file = File::Spec->catfile($folder, 'typemap');
		$self->{types}->write_typemap_file($typemap_file);
	}

	# some bindings merely bundle other bindings; they don't contain
	# actual bindings; we know we have one of these if we don't have
	# a cpp name
	if ($self->has('cpp_name')) {
		$self->generate_utility_h_code($folder);
		$self->generate_utility_cpp_code($folder);
	}
}

sub open_files {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	my @subpath = split /::/, $self->name;
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

#undef Copy // this macro might interfere with function names

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
	
	my $perl_module_name = $self->name;
	
	print { $self->{pmh} } <<END;
bootstrap $perl_module_name \$VERSION;

1;
END
}

sub generate_xs_postamble {
	my ($self) = @_;
	
	my $perl_module_name = $self->module_name;
	
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
