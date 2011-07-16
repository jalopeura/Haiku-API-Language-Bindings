package Python::Method;
use Python::Functions;
use strict;
our @ISA = qw(Method Python::Function);

sub generate_cc {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my $name = "${python_object_prefix}_" . $self->name;
	if ($self->has('overload_name')) {
		$name .= $self->overload_name;
	}
	
	$self->SUPER::generate_cc(
		name => $name,
		cpp_name => "python_self->cpp_object->$self->{name}",
		python_input => [
			"${python_object_prefix}_Object* python_self",
			'PyObject* python_args',
		],
		python_args => 'python_args',
	);
	
	my $doc;
	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	$self->class->add_method_table_entry(
		$self->name,		# name as seen from Python
		$name,				# name of wrapper function
		'METH_VARARGS',		# flags
		$doc				# docs
	);
}
#		$options{name} = "${python_object_prefix}_init";
#		$options{python_input}[0] = "${python_object_prefix}_Object* python_self";
#		$options{python_input}[2] = 'PyObject* python_kwds';	# __init__ always takes keywords, even though we don't do anything with them yet
#		$options{rettype} = 'int';
#		$options{comment} = <<COMMENT;

sub generate_cc_function {
	my ($self, $options, $funcname) = @_;
	$funcname ||= $self->name;
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my $args = delete $options->{arg_input};
	$options->{input} = "${python_object_prefix}_Object* python_self, $args";
	
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
			qq(python_self->cpp_object->$funcname($call_args););
				
		push @{ $options->{return_code} }, 
				qq(return Py_BuildValue(""););
	}
	else {
		my ($item, $arg, $defs, $code) = $self->params->as_cpp_return;
		
		push @{ $options->{input_defs} }, "$retval->{type} $retval->{name};", @$defs;
		
		push @{ $options->{code} }, 
				qq($retval->{name} = python_self->cpp_object->$funcname($call_args);),
				@$code;
				
		push @{ $options->{return_code} }, 
				qq(return Py_BuildValue("$item", $arg););
	}
	
	$self->SUPER::generate_cc_function($options);
	
	my $doc;
	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	$self->class->add_method_table_entry(
		$self->name,		# name as seen from Python
		$options->{name},	# name of wrapper function
		'METH_VARARGS',		# flags
		$doc				# docs
	);
}

1;
