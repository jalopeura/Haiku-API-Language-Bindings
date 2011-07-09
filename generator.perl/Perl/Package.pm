use Common::Bindings;
use Perl::BaseObject;

package Perl::Package;
use File::Spec;
use File::Path;
use Perl::Functions;
use Perl::Properties;
use Perl::Constants;
use strict;
our @ISA = qw(Binding Perl::BaseObject);

sub is_responder { 0 }

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->propagate_value('package', $self);
	
	if ($self->has('cpp_name')) {
		$self->propagate_value('cpp_class_name', $self->cpp_name);
		$self->propagate_value('perl_class_name', $self->perl_name);
	}
	
	# anything to export?
	my @exports;
	if ($self->has('functions')) {
		if ($self->functions->has('plains')) {
			for my $plain ($self->functions->plains) {
				push @exports, $plain->name;
			}
		}
	}
	if ($self->has('constants')) {
		if ($self->constants->has('constants')) {
			for my $constant ($self->constants->constants) {
				push @exports, $constant->name;
			}
		}
	}
	
	my @isa;
	if (@exports) {
		push @isa, 'Exporter';
		$self->{_exports} = \@exports;
	}
	
	# any parent classes?
	if ($self->has('perl_parent')) {
		my $perl_isa = $self->perl_parent;
		for my $parent (split /\s+/, $perl_isa) {
			push @isa, $parent;
		}
	}
	
	if (@isa) {
		$self->{_isa} = \@isa;
	}
}

sub generate {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	# if there's no perl name, we're just a bundle and there's nothing to
	# generate (makefile and typemap are handled by Perl::Module)
	return unless ($self->has('perl_name'));
	
	$self->open_files($folder, $pm_prefix, $xs_prefix);
	
	$self->generate_preamble;
	
	$self->generate_body;
	
	$self->generate_postamble;
	
	$self->close_files;
}

sub open_files {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	my @subpath = split /::/, $self->perl_name;
	my $filename = pop @subpath;

	my $xs_folder = File::Spec->catfile($folder, $xs_prefix, @subpath);
	my $pm_folder = File::Spec->catfile($folder, $pm_prefix, @subpath);
	
	mkpath($xs_folder);
	mkpath($pm_folder);
	
	# PM file
	my $pm_filename = File::Spec->catfile($pm_folder, "$filename.pm");
	open $self->{pmh}, ">$pm_filename" or die "Unable to create file '$pm_filename': $!";
	
	# XS file
	my $xs_filename = File::Spec->catfile($xs_folder, "$filename.xs");
	open $self->{xsh}, ">$xs_filename" or die "Unable to create file '$xs_filename': $!";
	
	$self->{xs_include} = join('/', $xs_prefix, @subpath, "$filename.xs");
	
	$self->{filename} = $filename;
}

sub generate_preamble {
	my ($self) = @_;
	
	$self->generate_pm_preamble;
	$self->generate_xs_preamble;
}

sub generate_body {
	my ($self) = @_;
	
	#
	# functions
	#
	
	if ($self->has('functions')) {
		$self->functions->generate;
	}
	
	#
	# properties
	#
	
	if ($self->has('properties')) {
		$self->properties->generate;
	}
	
	#
	# constants
	#
	
	if ($self->has('constants')) {
		$self->constants->generate;
	}
}

sub generate_postamble {
	my ($self) = @_;
	
	$self->generate_pm_postamble;
	$self->generate_xs_postamble;
}

sub close_files {
	my ($self) = @_;
	close $self->{pmh};
	close $self->{xsh};
}

#
# PM-specific sections
#

sub generate_pm_preamble {
	my ($self) = @_;
	
	my $perl_class_name = $self->perl_name;
	
	print { $self->{pmh} } <<TOP;
#
# Automatically generated file
#

package $perl_class_name;
use strict;
use warnings;
TOP
	
	# if we're a top-level package, we need to be a DynaLoader
	if ($self->has('name')) {
		print  { $self->{pmh} } "require DynaLoader;\n"
	}
	
	if ($self->has('_exports')) {
		print  { $self->{pmh} } "require Exporter;\n"
	}
	
	print { $self->{pmh} } "\nour \$VERSION = $self->{version};\n";
	
	if ($self->has('_isa')) {
		my $isa = join(' ', $self->_isa);
		print { $self->{pmh} } "our \@ISA = qw($isa);\n";
	}
	
	if ($self->has('_exports')) {
		my $exp = join(' ', $self->_exports);
		print { $self->{pmh} } "our \@EXPORT_OK = qw($exp);\n";
	}
	
	print { $self->{pmh} } "\n";
}

sub generate_pm_postamble {
	my ($self) = @_;
	
	print { $self->{pmh} } "1;\n";
}

#
# XS-specific sections
#

sub generate_xs_preamble {
	my ($self) = @_;
	
	my $perl_class_name = $self->perl_name;
	my $perl_module_name = $self->module_name;
	
	print { $self->{xsh} } <<TOP;
#
# Automatically generated file
#

MODULE = $perl_module_name	PACKAGE = $perl_class_name

TOP
}

sub generate_xs_postamble {} # nothing to do

1;
