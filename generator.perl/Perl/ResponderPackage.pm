package Perl::ResponderPackage;
use Perl::Package;
use strict;
our @ISA = qw(Perl::Package);

sub is_responder { 1 }

sub _upgrade {
	my ($class, $prefix, $package) = @_;
	
	# ResponderPackage is upgraded from Package, not from Binding
	my $self = $class->SUPER::_upgrade($prefix, $package->{_upgraded_from});
	
	return $self;
}

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->{cpp_parent} = $self->{cpp_name};
	$self->{cpp_name} = 'Custom_' . $self->{cpp_name};
	$self->{perl_parent} = $self->{perl_name};
	$self->{perl_name}=~s/([^:]+)$/Custom$1/;
	
	# responders only need events; they inherit the rest
	for my $functype (qw(methods statics plains)) {
		delete $self->{functions}{$functype};
	}

	delete $self->{constants};
	delete $self->{properties};
	
	$self->SUPER::finalize_upgrade;
	
	return $self;
}

sub open_files {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	$self->SUPER::open_files($folder, $pm_prefix, $xs_prefix);
	
	my @subpath = split /::/, $self->perl_name;
	my $filename = pop @subpath;
	my $xs_folder = File::Spec->catfile($folder, $xs_prefix, @subpath);
	
	# H file
	my $h_filename = File::Spec->catfile($xs_folder, "$filename.h");
	open $self->{hh}, ">$h_filename" or die "Unable to create file '$h_filename': $!";
	
	# CPP file
	my $cpp_filename = File::Spec->catfile($xs_folder, "$filename.cpp");
	open $self->{cpph}, ">$cpp_filename" or die "Unable to create file '$cpp_filename': $!";
	
	$self->{cpp_include} = join('/', $xs_prefix, @subpath, "$filename.cpp");
}

sub generate_preamble {
	my ($self) = @_;
	
	$self->SUPER::generate_preamble;
	
	$self->generate_h_preamble;
	$self->generate_cpp_preamble;
}

sub generate_postamble {
	my ($self) = @_;
	
	$self->SUPER::generate_postamble;
	
	$self->generate_h_postamble;
	$self->generate_cpp_postamble;
}

sub generate_h_preamble {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_name;
	my $cpp_parent_name = $self->cpp_parent;
	
	print { $self->package->hh } <<PRE;
/*
 * Automatically generated file
 */

class $cpp_class_name : public $cpp_parent_name {
	public:
PRE
}

sub generate_h_postamble {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_name;
	
	print { $self->package->hh } <<POST;
		object_link_data* perl_link_data;
}; // $cpp_class_name
POST
}

sub generate_cpp_preamble {
	my ($self) = @_;
	
	my ($include) = $self->perl_name=~/([^:]+)$/;
	
	print { $self->package->cpph } <<PRE;
/*
 * Automatically generated file
 */

#include "$include.h"

PRE
}

sub generate_cpp_postamble {}	# nothing to do

1;
