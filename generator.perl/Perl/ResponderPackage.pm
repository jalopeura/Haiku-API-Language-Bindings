package Perl::ResponderPackage;
use File::Spec;
use Perl::Package;
require Perl::HCodeGenerator;
require Perl::CPPCodeGenerator;
use strict;
our @ISA = qw(Perl::Package);

sub parse_binding {
	my ($self, $binding) = @_;
	
	my @n = split /::/, $binding->target;
	$n[-1] = "Custom$n[-1]";
	
	$self->{name} = join('::', @n);
	$self->{cpp_class} = 'Custom_' . $binding->{source};
	$self->{cpp_parent} = $binding->{source};
	$self->{type} = 'responder_ptr';
	
	$self->{isa} = [ $binding->target ];
	
	$self->{version} ||= $binding->{version} || $self->{module}->{version};
	
	$self->{binding} = $binding;
}

sub open_files {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	$self->SUPER::open_files($folder, $pm_prefix, $xs_prefix);
	
	my @subpath = split /::/, $self->{name};
	my $filename = pop @subpath;
	my $xs_folder = File::Spec->catfile($folder, $xs_prefix, @subpath);
	
	# H file
	my $h_filename = File::Spec->catfile($xs_folder, "$filename.h");
	open $self->{hh}, ">$h_filename" or die "Unable to create file '$h_filename': $!";
	
	# CPP file
	my $cpp_filename = File::Spec->catfile($xs_folder, "$filename.cpp");
	open $self->{cpph}, ">$cpp_filename" or die "Unable to create file '$cpp_filename': $!";
	
	$self->{cpp_include} = File::Spec->catfile($xs_prefix, @subpath, "$filename.cpp");
}

sub close_files {
	my ($self) = @_;
	close $self->{pmh};
	close $self->{xsh};
	close $self->{hh};
	close $self->{cpph};
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

sub generate_functions {
	my ($self) = @_;
	my $binding = $self->{binding};
	
	#
	# functions
	# (constructor, destructor, object methods, object event methods,
	#    class methods, plain functions)
	#
	
	my @functions;
	
	if ($binding->constructors) {
		push @functions, $binding->constructors;
	}
	if ($binding->destructor) {
		push @functions, $binding->destructor;
	}
	
	for my $function (@functions) {
		my $params = $self->parse_params($function);
		$self->generate_xs_function($function, $params);
		$self->generate_h_method($function, $params);
		$self->generate_cpp_method($function, $params);
	}
	
	if ($binding->events) {
		for my $event ($binding->events) {
			my $params = $self->parse_params($event);
			$self->generate_h_method($event, $params);
			$self->generate_cpp_method($event, $params);
		}
	}
}
