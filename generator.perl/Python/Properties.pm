use Common::Properties;
use Python::BaseObject;

package Python::Properties;
use strict;
our @ISA = qw(Properties Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('properties')) {
		for my $p ($self->properties) {
			$p->generate;
		}
	}
}

package Python::Property;
use strict;
our @ISA = qw(Property Python::BaseObject);

sub type {
	my ($self) = @_;
	unless ($self->{type}) {
		my $t = $self->{type_name};
		if ($self->{needs_deref}) {
			$t=~s/\*$//;
		}
		$self->{type} = $self->types->type($t);
	}
	return $self->{type};
}

#%options = (
#	name
#	default
#	count/length = {
#		name
#		type
#	}
#	must_not_delete
#)

sub type_options {
	my ($self) = @_;
	my $options = {
		name => 'python_self->cpp_object->' . $self->name,
		must_not_delete => 1,
	};
	if ($self->has('repeat')) {
		$options->{repeat} = $self->repeat;
	}
	return $options;
}

sub arg_builder {
	my ($self, $options, $repeat) = @_;
	return $self->type->arg_builder($options, $repeat);
}

sub arg_parser {
	my ($self, $options, $repeat) = @_;
	return $self->type->arg_parser($options, $repeat);
}

sub generate {
	my ($self) = @_;
	
	(my $class_name = $self->class->python_name)=~s/\./_/g;
	$class_name .= '_Object';
	my $property_name = $self->name;
	my $type = $self->type;
	my $property_type = $type->name;
	my $item = $type->format_item;
	
	my $getter_name = "${class_name}_get$property_name";
	my $setter_name = "${class_name}_set$property_name";

=pod

	$class_name .= '_Object';
	
	my $get_var = my $set_var = "python_self->cpp_object->$property_name";
	
	my $pre_get = my $pre_set = "// no conversion necessary";
		
	# some types are parsed as Python objects; deal with them here
	if ($item=~/^O/) {
		my $builtin = $type->builtin;
		my $target;
		if ($type->has('target')) {
			$target = $type->target;
		}
		if ($builtin eq 'bool') {
			$item = 'b';
			$get_var = "(self->cpp_object->$property_name ? 1 : 0)";
			$set_var = "(bool)(PyObject_IsTrue(value))";
		}
		elsif ($target) {
			(my $pytype = $target)=~s/\./_/g; $type .= '_Object';
			$get_var = "py_$property_name";
			$pre_get = "$pytype* py_$property_name;
	py_$property_name = new $type();
	py_$property_name->cpp_object = self->cpp_object->$property_name;";
			$set_var = "(($type*)value)->cpp_object";
		}
		else {
			warn "Unsupported type: $property_type/$builtin/$target";
		}
	}
	
	if ($item=~/[ibhlBH]/) {
		$set_var = "($property_type)PyInt_AsLong(value)";
	}
	elsif ($item=~/[Ik]/) {
		$set_var = "($property_type)PyLong_AsLong(value)";
	}
	elsif ($item=~/[fd]/) {
		$set_var = "($property_type)PyFloat_AsDouble(value)";
	}
	elsif ($item=~/[s]/) {
		$set_var = "($property_type)PyString_AsString(value)";
	}
	else {
		warn "Unsupported type: $property_type ($item)";
	}
	
	print { $self->class->cch } <<PROP;
/*
static PyObject* $getter_name($class_name* python_self, void* python_closure) {
	$pre_get
	return Py_BuildValue("$item", $get_var);
}

static int $setter_name($class_name* python_self, PyObject* value, void* closure) {
	$pre_set
	self->cpp_object->$property_name = $set_var;
	return 0;	// really should be doing some kind of checking here
}
*/

PROP

=cut

	
	my $fh = $self->class->cch;
	
#	my ($get_fmt, $get_arg, $get_defs, $get_code) = $self->arg_builder;
	my $get_fmt = $self->type->format_item;
	my $get_arg = 'py_' . $self->name;
	my $options = {
		input_name => 'python_self->cpp_object->' . $self->name,
		output_name => $get_arg,
		must_not_delete => 1,
		repeat => $self->has('repeat') ? $self->repeat : 0,
	};
	my ($get_defs, $get_code) = $self->arg_builder($options);
	print $fh qq(static PyObject* $getter_name($class_name* python_self, void* python_closure) {\n);
	print $fh map { "\t$_\n" } @$get_defs;
	print $fh map { "\t$_\n" } @$get_code;
	print $fh qq(\treturn $get_arg;\n);
	print $fh "}\n\n";

#	my ($set_fmt, $set_arg, $set_defs, $set_code) = $self->arg_parser('value');
	my $set_fmt = $self->type->format_item;
	my $options = {
		input_name => 'value',
		output_name => 'python_self->cpp_object->' . $self->name,
		repeat => $self->has('repeat') ? $self->repeat : 0,
	};
	my ($set_defs, $set_code) = $self->arg_parser($options);
	print $fh qq(static int $setter_name($class_name* python_self, PyObject* value, void* closure) {\n);
#	if (not $self->has('repeat') and not $self->type->has('repeat')) {
#		print $fh "\tPyObject* tuple = PyTuple_Pack(1, value);\n";
#	}
	print $fh map { "\t$_\n" } @$set_defs;
	print $fh map { "\t$_\n" } @$set_code;
#	if (not $self->has('repeat') and not $self->type->has('repeat')) {
#		print $fh qq(\tPyArg_ParseTuple(tuple, "$set_fmt", $set_arg);\n);
#	}
	print $fh "\treturn 0;\n";	# do we need error checks, or will Python raise an exception for us?
	print $fh "}\n\n";
	
	push @{ $self->class->{property_table } }, qq({ (char*)"$property_name", (getter)$getter_name, (setter)$setter_name, (char*)"<DOC>", NULL});
}

1;
