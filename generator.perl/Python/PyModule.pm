package Python::PyModule;
use File::Spec;
use File::Path;
use Python::PyType;
use Python::ResponderPyType;
use Python::Params;
require Python::PYCodeGenerator;
require Python::CCodeGenerator;
use strict;

sub new {
	my ($class, $package, $binding, $types) = @_;
	my $self = bless {
		package => $package,
		types   => $types,
		children => [],
		method_table => [],
		constant_defs => [],
		constant_code => [],
	}, $class;
	
	$self->parse_binding($binding);
	
	return $self;
}

sub parse_binding {
	my ($self, $binding) = @_;
	
	($self->{name} = $binding->target)=~s/::/./g;
	
	# if we have a constructor, we need a PyType
	if ($binding->constructors) {
		push @{ $self->{children} }, new Python::PyType($self, $self->{package}, $binding, $self->{types});
	}
	
	# if we have events, we need a ResponderPyType
	if ($binding->events) {
		push @{ $self->{children} }, new Python::ResponderPyType($self, $self->{package}, $binding, $self->{types});
	}
	
	$self->{binding} = $binding;
}

sub open_files {
	my ($self, $folder) = @_;
	
	my @subpath = split /\./, $self->{name};
	my $filename = pop @subpath;
	my $ext_folder = File::Spec->catfile($folder, @subpath);
	
	mkpath($ext_folder);
	
	# PY file
#	my $py_filename = File::Spec->catfile($ext_folder, "$filename.py");
#	open $self->{pyh}, ">$py_filename" or die "Unable to create file '$py_filename': $!";
	
	# C file
	my $c_filename = File::Spec->catfile($ext_folder, "$filename.cc");
	open $self->{ch}, ">$c_filename" or die "Unable to create file '$c_filename': $!";
	
	$self->{filename} = $filename;
	
	$self->{c_include} = File::Spec->catfile(@subpath, "$filename.cc");
}

sub close_files {
	my ($self) = @_;
	close $self->{pyh};
	close $self->{ch};
}

sub generate {
	my ($self, $folder) = @_;
	
	# if we're just a bundle, we may not have any files to generate
	return unless ($self->{binding});
	
	# generate children before self, so packages can report filenames and method names
	for my $child (@{ $self->{children} }) {
		$child->generate($folder);
	}
	
	$self->open_files($folder);
	
	$self->generate_preamble;
	
	$self->generate_functions;
	
	$self->generate_postamble;
	
	$self->close_files;
}

sub generate_preamble {
	my ($self) = @_;
	
#	$self->generate_py_preamble;
	$self->generate_c_preamble;
}

sub generate_postamble {
	my ($self) = @_;
	
#	$self->generate_py_postamble;
	$self->generate_c_postamble;
}

sub generate_functions {
	my ($self) = @_;
	my $binding = $self->{binding};
	
	#
	# plain functions
	#
	
	for my $function ($binding->plains) {
		my $params = $self->parse_params($function->params);
		$self->generate_c_function($function, $params);
	}
	
	#
	# constants
	#
	
	for my $constant ($binding->constants) {
		$self->generate_c_constant($constant);
	}
}

1;

__END__

Need to put this in c_preamble or c_postamble for PyModules
	
		my @meth = split /\./, $python_module_name;
		my $methods = join('_', @meth, 'Object_Methods[]');
		print $basic_c_file "static PyMethodDef $methods = (\n";
		for my $method (@{ $self->{method_tables}{basic} }) {
			print $basic_c_file qq(\t{"$method->[0]",  $method->[1], $method->[2], "$method->[3]"},\n);
		}
		print $basic_c_file <<END;
	{NULL, NULL, 0, NULL}
);

END
