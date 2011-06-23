package Python::ResponderPyType;
use File::Spec;
use Python::PyType;
require Python::HCodeGenerator;
require Python::CPPCodeGenerator;
use strict;
our @ISA = qw(Python::PyType);

sub parse_binding {
	my ($self, $binding) = @_;
	
	my @n = split /::/, $binding->target;
	
	$self->{name} = join('.', @n, "Custom$n[-1]");
	$self->{cpp_class} = 'Custom_' . $binding->{source};
	$self->{cpp_parent} = $binding->{source};
	
	$self->{python_class} = $self->{name};
	$self->{python_parent} = join('.', @n, $n[-1]);
	
	$self->{type} = 'responder_ptr';
	
	$self->{binding} = $binding;
}

sub open_files {
	my ($self, $folder) = @_;
	
	$self->SUPER::open_files($folder);
	
	my @subpath = split /\./, $self->{name};
	my $filename = pop @subpath;
	my $ext_folder = File::Spec->catfile($folder, @subpath);
	
	# H file
	my $h_filename = File::Spec->catfile($ext_folder, "$filename.h");
	open $self->{hh}, ">$h_filename" or die "Unable to create file '$h_filename': $!";
	
	# CPP file
	my $cpp_filename = File::Spec->catfile($ext_folder, "$filename.cpp");
	open $self->{cpph}, ">$cpp_filename" or die "Unable to create file '$cpp_filename': $!";
	
	$self->{h_include} = File::Spec->catfile(@subpath, "$filename.h");
	$self->{cpp_include} = File::Spec->catfile(@subpath, "$filename.cpp");
}

sub close_files {
	my ($self) = @_;
	close $self->{pyh};
	close $self->{ch};
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
		my $params = new Python::Params($function, $self->{types});
		$self->generate_c_function($function, $params);
		$self->generate_h_method($function, $params);
		$self->generate_cpp_method($function, $params);
	}
	
	if ($binding->events) {
		for my $event ($binding->events) {
			my $params = new Python::Params($event, $self->{types});
			$self->generate_h_method($event, $params);
			$self->generate_cpp_method($event, $params);
		}
	}
}

1;
