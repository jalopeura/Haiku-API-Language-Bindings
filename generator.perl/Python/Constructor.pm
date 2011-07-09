package Python::Constructor;
use Python::Functions;
use strict;
our @ISA = qw(Constructor Python::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'new';
}

sub generate_cc_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my $args = delete $options->{arg_input};
	
	$options->{code} ||= [];
	$options->{input_defs} ||= [];
	
	if ($self->has('overload_name')) {
		$options->{input} = "PyTypeObject* python_type, $args";
		
		push @{ $options->{input_defs} }, "${python_object_prefix}_Object* python_self;";
		
		push @{ $options->{code} },
			qq(python_self = (${python_object_prefix}_Object*)python_type->tp_alloc(python_type, 0););
		
		my $doc;
		if ($self->has('doc')) {
			$doc = $self->doc;
		}
		$self->class->add_method_table_entry(
			$self->overload_name,	# name as seen from Python
			$options->{name},		# name of wrapper function
			'METH_VARARGS|METH_CLASS',	# flags
			$doc					# docs
		);
	}
	else {
		$options->{name} = "${python_object_prefix}_init";
		$options->{rettype} = 'int';
		$options->{input} = "${python_object_prefix}_Object* python_self, $args, PyObject* python_kwds";
		
		$options->{comment} = <<COMMENT;
/*
 * The main constructor is implemented in terms of __init__(). This allows
 * __new__() to return an empty object, so when we pass to Python an object
 * from the system (rather than one we created ourselves), we can use
 * __new__() and assign the already existing C++ object to the Python object.
 *
 * This does somewhat expose us to the danger of Python code calling
 * __init__() a second time, so we need to check for that.
 */
COMMENT
		
		unshift @{ $options->{code} },
			qq(// dont't let python code call us a second time),
			qq(if (python_self->cpp_object != NULL)),
			qq(	return -1;),
	}
	
	if (@{ $options->{code} }) {
		push @{ $options->{code} }, '';
	}
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	
	push @{ $options->{code} },
		qq{python_self->cpp_object = new $cpp_class_name($call_args);};
	
	if ($self->class->is_responder) {
		push @{ $options->{code} },
			qq{python_self->cpp_object->python_object = python_self;};
	}
	
	if ($self->class->must_not_delete) {
		push @{ $options->{code} },
			qq{// we don't own this object, so we can't delete it},
			qq{python_self->can_delete_cpp_object = false;};
	}
	else {
		push @{ $options->{code} },
			qq{// we own this object, so we can delete it},
			qq{python_self->can_delete_cpp_object = true;};
	}
	
	if ($self->has('overload_name')) {
		push @{ $options->{return_code} }, qq(return Py_BuildValue("O", python_self););
	}
	else {
		push @{ $options->{return_code} }, qq(return 0;);
	}
	
	$self->SUPER::generate_cc_function($options);
}

sub generate_h {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	print { $self->class->hh } qq(\t\t$cpp_class_name($inputs);\n);
}

sub generate_cpp {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	my $cpp_parent_name = $self->class->cpp_parent;

	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	my $parent_inputs = join(', ', @{ $self->params->as_cpp_parent_input });
	
	print { $self->class->cpph } <<CONSTRUCTOR;
${cpp_class_name}::$cpp_class_name($inputs)
	: $cpp_parent_name($parent_inputs) {}

CONSTRUCTOR
}

1;
