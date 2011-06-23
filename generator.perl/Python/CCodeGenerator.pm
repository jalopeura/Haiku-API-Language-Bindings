package Python::PyModule;
use strict;

use constant TYPE_MAIN_CONSTRUCTOR => 1;
use constant TYPE_DESTRUCTOR       => 2;
use constant TYPE_CLASS_METHOD     => 3;
use constant TYPE_MODULE_METHOD    => 4;

sub generate_c_preamble {
	my ($self) = @_;
	
	print { $self->{ch} } <<TOP;
/*
 * Automatically generated file
 */

TOP
}

sub generate_c_function {
	my ($self, $function, $params) = @_;
	
	my $fh = $self->{ch};
	my $cpp_class_name = $self->{cpp_class};
	my $cpp_parent_name = $self->{cpp_parent};
	my $python_package_name = $self->{package}{name};
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_';
	
	my (
		@var_defs, @inputs_to_cpp, $output_from_cpp,
		@inputs_from_python, $python_input_format, @post_input_parse,
		@outputs_to_python, $python_output_format, @pre_output_build,
	);
	
	my $opt;
	for my $p (@{ $params->cpp_inputs }) {
		my $param = $p->as_input_to_cpp;
		
		if ($param->{is_optional} and not $opt) {
			$python_input_format .= '|';
			$opt = 1;
		}
		
		$python_input_format .= $param->{format_item};
		
		push @inputs_to_cpp, $param->{name};
		
		if ($param->{definition}) {
			push @var_defs, $param->{definition};
		}
		if ($param->{format_name}) {
			push @inputs_from_python, $param->{format_name};
		}
		if ($param->{format_definition}) {
			push @var_defs, $param->{format_definition};
		}
		if ($param->{format_code}) {
			push @post_input_parse, @{ $param->{format_code} };
		}
	}
	
	for my $p (@{ $params->python_outputs }) {
		my $param = $p->as_output_to_python;
		
		next if $param->{type} eq 'void';
		
		$python_output_format .= $param->{format_item};
		push @outputs_to_python, $param->{format_name};
		
		if ($param->{definition}) {
			push @var_defs, $param->{definition};
		}
		if ($param->{format_definition}) {
			push @var_defs, $param->{format_definition};
		}
		if ($param->{format_code}) {
			push @pre_output_build, @{ $param->{format_code} };
		}
	}
	
#	my ($fname, @cpp_pre_parse, @cpp_code, @ret_code, $method_type, $python_c_inputs);
	my ($fname, @cpp_pre_parse, @cpp_code, @ret_code, $method_type, $python_c_inputs);
	my $inputs_to_cpp = join(', ', @inputs_to_cpp);
	
	if ($function->isa('Constructor')) {		
		push @var_defs, "${name}Object* python_self";
		$python_output_format = 'O' . $python_output_format;
		unshift @outputs_to_python, 'python_self';
		
		$fname = 'new';
		if ($function->overload_name) {
			$fname .= $function->overload_name;
			$method_type = TYPE_MODULE_METHOD;
			# might want to determine here whether we accept any arguments
			$python_c_inputs = 'PyObject* python_module, PyObject* python_args';
#print $self->{module},"\n";
			my ($cname) = $self->{name}=~/([^.]+)$/;
			$cname .= $function->overload_name;
			push @{ $self->{module}{method_table} }, qq({"$cname", (PyCFunction)$name$fname, METH_VARARGS, "..."});
			
			if (@post_input_parse) {
				push @post_input_parse, '',
			}
			push @post_input_parse,
				qq(python_self = new ${name}Object;);
		}
		else {
			$method_type = TYPE_MAIN_CONSTRUCTOR;
			$python_c_inputs = 'PyTypeObject* python_type, PyObject* python_args, PyObject* python_kwds';
			
			if (@post_input_parse) {
				push @post_input_parse, '',
			}
			push @post_input_parse,
				qq(python_self = (${name}Object*)python_type->tp_alloc(python_type, 0););
		}
		$name .= $fname;
		
		# here we need to actually create the object
		push @cpp_code, qq(python_self->cpp_object = new $cpp_class_name($inputs_to_cpp););
		
		# set python_object for our custom c++ objects
		if ($self->isa('Python::ResponderPyType')) {
			push @cpp_code, qq(python_self->cpp_object->python_object = python_self;);
		}
		
		# handle must-not-delete values
		if ($self->{binding}{'must-not-delete'}) {
			push @cpp_code,
				qq(),
				qq(// cannot delete this object; we do not own it),
				qq(python_self->can_delete_cpp_object = false;);
		}
		else {
			push @cpp_code,
				qq(),
				qq(// we own this object, so we can delete it),
				qq(python_self->can_delete_cpp_object = true;);
		}
	}
	elsif ($function->isa('Destructor')) {		
		$method_type = TYPE_DESTRUCTOR;
		$python_c_inputs = "${name}Object* self";
		$fname = 'DESTROY';
		$name .= $fname;
		push @cpp_code, qq(if (self->can_delete_cpp_object) {),
			qq(\tdelete self->cpp_object;),
			qq(\tself->cpp_object = NULL;),
			qq(\tself->can_delete_cpp_object = false;),
			qq(});
	}
	elsif ($function->isa('Method') or $function->isa('Event')) {
		$method_type = TYPE_CLASS_METHOD;
		# might want to determine here whether we accept any arguments
		$python_c_inputs = "${name}Object* python_self, PyObject* python_args";
		$fname = $function->name;
		$name .= $fname;
		push @{ $self->{method_table} }, qq({"$fname", (PyCFunction)$name, METH_VARARGS, "..."});
		
		if ($function->isa('Event')) {
			$fname = "${cpp_class_name}::$fname";
			push @cpp_code, qq(// force base class version of virtual method);
		}
		
		$output_from_cpp = $params->cpp_output->as_output_to_python;
		if ($output_from_cpp->{type} eq 'void') {
			push @cpp_code, qq(python_self->cpp_object->$fname($inputs_to_cpp););
		}
		else {
			my $retname = $output_from_cpp->{name};
			my $pyretname = $output_from_cpp->{pyobject_name};
			push @cpp_code, qq($retname = python_self->cpp_object->$fname($inputs_to_cpp););
		}
	}
	elsif ($function->isa('Static')) {
		$output_from_cpp = $params->cpp_output->as_output_to_python;
		# might want to determine here whether we accept any arguments
		$python_c_inputs = 'PyObject* python_class, PyObject* python_args';
		$fname = $function->name;
		$name .= $function->name;
		push @{ $self->{method_table} }, qq({"$fname", (PyCFunction)$name, METH_VARARGS, "..."});
		
		if ($output_from_cpp->{type} eq 'void') {
			push @cpp_code, qq(${cpp_class_name}::$fname($inputs_to_cpp););
		}
		else {
			my $retname = $output_from_cpp->{name};
			push @cpp_code, qq($retname = ${cpp_class_name}::$fname($inputs_to_cpp););
		}
	}
	elsif ($function->isa('Plain')) {
		$output_from_cpp = $params->cpp_output->as_output_to_python;
		# might want to determine here whether we accept any arguments
		$python_c_inputs = 'PyObject* python_module, PyObject* python_args';
		$fname = $function->name;
		$name .= $function->name;
		push @{ $self->{method_table} }, qq({"$fname", (PyCFunction)$name, METH_VARARGS, "..."});
		
		if ($output_from_cpp->{type} eq 'void') {
			push @cpp_code, qq($fname($inputs_to_cpp););
		}
		else {
			my $retname = $output_from_cpp->{name};
			push @cpp_code, qq($retname = $fname($inputs_to_cpp););
		}
	}
	
	my $tables;
	if ($function->isa('Method') or $function->isa('Event')) {
		$tables = $self->{method_tables};
	}
	else {
		$tables = $self->{function_tables};
	}
	push @{ $tables->{basic} }, [
		$fname,
		$name,
		'METH_VARARGS',
		'',
	];
	
	my $python_c_rettype = $method_type == TYPE_DESTRUCTOR ? 'void' : 'PyObject*';
	
	print $fh <<TOP;
//static $python_c_rettype $name($python_c_inputs);
static $python_c_rettype $name($python_c_inputs)
{
TOP
	
	if (@var_defs) {
		print $fh qq(\t// var defs\n);
		for my $line (@var_defs) {
			print $fh "\t$line;\n";
		}
#print $fh "\t// END: var defs";
		print $fh "\n";
	}
		
	if (@inputs_from_python) {
		print $fh "\t// extract the arguments from the args object (a Python tuple)\n";
		my $parse_args = join(', ', qq("$python_input_format"), @inputs_from_python);
		#print $fh qq(\tint ok = PyArg_ParseTuple(python_args, $parse_args);\n\n);
		# should check the return value, but for now it just generates warnings
		print $fh qq(\tPyArg_ParseTuple(python_args, $parse_args);\n\n);
	}
	
	# post-parse data massaging
	if (@post_input_parse) {
		print $fh "\t// massage data after parsing tuple\n";
		for my $line (@post_input_parse) {
			print $fh "\t$line\n";
		}
#print $fh "\t// END: massage data after parsing tuple";
		print $fh "\n";
	}
	
	print $fh qq(\t// wrapped functionality\n);
	for my $line (@cpp_code) {
		print $fh "\t$line\n";
	}
#print $fh qq(\t// END: wrapped functionality);
	print $fh "\n";
	
	# error processing
	if (@{ $params->python_errors }) {
		print $fh "\t// check for errors\n";
		my @e = split /\./, $python_package_name;
		my $errvar = $e[-1] . 'Error';
		for my $p (@{ $params->python_errors }) {
			my $param = $p->as_error_to_python;
			print $fh <<ERR;
	if ($param->{name} != $param->{success}) {
		PyObject* errval = Py_BuildValue("$param->{format_item}", $param->{name});
		PyErr_SetObject($errvar, errval);
		return NULL;
	}
ERR
		}
	}
	
	# pre-build data massaging
	if (@pre_output_build) {
		print $fh "\t// massage data before building return value\n";
		for my $line (@pre_output_build) {
			print $fh "\t$line\n";
		}
#print $fh "\t// END: massage data before building return value";
		print $fh "\n";
	}
	
	# return values
	if ($python_c_rettype ne 'void') {
		print $fh qq(\t// build Python return values\n);
		my $build_args = join(', ', qq("$python_output_format"), @outputs_to_python);
		print $fh qq(\treturn Py_BuildValue($build_args);\n);
	}
	print $fh "}\n\n";
}

sub generate_c_property {
	my ($self, $property) = @_;
	
	(my $class_name = $self->{name})=~s/\./_/g;
	my $property_name = $property->{name};
	my $property_type = $property->{type};
	my $item = $self->{types}->get_format_item($property_type);
	
	my $getter_name = "${class_name}_get$property_name";
	my $setter_name = "${class_name}_set$property_name";
	
	$class_name .= '_Object';
	
	my $get_var = my $set_var = "self->cpp_object->$property_name";
	
	my $pre_get = my $pre_set = "// no conversion necessary";
		
	# some types are parsed as Python objects; deal with them here
	if ($item=~/^O/) {			
		my ($builtin, $target) = $self->{types}->get_builtin($property_type);
		if ($builtin eq 'bool') {
			$item = 'b';
			$get_var = "(self->cpp_object->$property_name ? 1 : 0)";
			$set_var = "(bool)(PyObject_IsTrue(value))";
		}
		elsif ($builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
			(my $type = $target)=~s/\./_/g; $type .= '_Object';
			$get_var = "py_$property_name";
			$pre_get = "$type* py_$property_name;
	py_$property_name = new $type();
	py_$property_name->cpp_object = self->cpp_object->$property_name;";
			$set_var = "(($type*)value)->cpp_object";
		}
		else {
			die "Unsupported type: $property_type/$builtin/$target";
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
	else {
		die "Unsupported type: $property_type ($item)";
	}
	
	print { $self->{ch} } <<PROP;
static PyObject* $getter_name($class_name* self, void* closure) {
	$pre_get
	return Py_BuildValue("$item", $get_var);
}

static int $setter_name($class_name* self, PyObject* value, void* closure) {
	$pre_set
	self->cpp_object->$property_name = $set_var;
	return 0;	// really should be doing some kind of checking here
}
PROP
	
	push @{ $self->{property_table } }, qq({ "$property_name", (getter)$getter_name, (setter)$setter_name, "<DOC>", NULL});
}

sub generate_c_constant {
	my ($self, $constant) = @_;
	
	(my $module_name = $self->{name})=~s/\./_/g;
	my $constant_name = $constant->{name};
	my $object_name = "${module_name}_$constant_name";
	
	push @{ $self->{constant_defs} }, "PyObject* $object_name;";
	push @{ $self->{constant_code} },
		qq(PyObject* $object_name = PyInt_FromLong((long)$constant_name);),
		qq(Py_INCREF($object_name);),
		qq(PyModule_AddObject(\%MODULE\%, "$constant_name", $object_name);),
		"";
}

sub generate_c_postamble {
	my ($self) = @_;
	
	my $fh = $self->{ch};
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_';
	
	# methods table
	print $fh qq(static PyMethodDef ${name}methods[] = {\n);
	for my $def (@{ $self->{method_table} }) {
		print $fh "\t$def,\n";
	}
	print $fh "\t{NULL} /* Sentinel */\n};\n\n";
}

1;
