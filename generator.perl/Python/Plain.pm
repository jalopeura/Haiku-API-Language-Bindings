package Python::Plain;
use Python::Functions;
use strict;
our @ISA = qw(Plain Python::Function);

sub generate_cc {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my $name = "${python_object_prefix}_" . $self->name;
	my $python_name = $self->name;
	if ($self->has('overload_name')) {
		$name = "${python_object_prefix}_" . $self->overload_name;
		$python_name = $self->overload_name;
	}
	
	$self->SUPER::generate_cc(
		name => $name,
		cpp_name => $self->name,
		python_input => [
			'PyObject python_dummy',
			'PyObject* python_args',
		],
		python_args => 'python_args',
	);
	
	my $doc;
	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	$self->class->add_method_table_entry(
		$python_name,		# name as seen from Python
		$name,				# name of wrapper function
		'METH_VARARGS|METH_STATIC',		# flags
		$doc				# docs
	);
}

sub generate_cc_function {
	my ($self, $options) = @_;
	my $funcname = $self->name;
	my $package_name = $self->package_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my $args = delete $options->{arg_input};
	$options->{input} = "Py_Object* python_dummy, $args";
	
	my ($retval, $void_return);
	if ($self->params->has('cpp_output')) {
		$retval = $self->params->cpp_output;
		$void_return = $retval->type eq 'void';
	}
	else {
		$void_return = 1;
	}
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	
	if ($void_return) {
		push @{ $options->{code} },
			qq($funcname($call_args););
				
		push @{ $options->{return_code} }, 
				qq(return Py_BuildValue(""););
	}
	else {
		my ($item, $arg, $defs, $code) = $self->params->as_cpp_return;
		
		push @{ $options->{input_defs} }, "$retval->{type} $retval->{name};", @$defs;
		
		push @{ $options->{code} }, 
				qq($retval->{name} = $funcname($call_args);),
				@$code;
				
		push @{ $options->{return_code} }, 
				qq(return Py_BuildValue("$item", $arg););
	}
	
	# for Python, plain functions are removed from the python class and
	# placed in the package. But the base generator class still expects a
	# class member when the plain function is generated
	$self->{class} = $self->package;
	$self->SUPER::generate_cc_function($options);
	delete $self->{class};
	
	my $doc;
	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	$self->package->add_method_table_entry(
		$self->name,		# name as seen from Python
		$options->{name},	# name of wrapper function
		'METH_VARARGS',		# flags
		$doc				# docs
	);
}

1;
