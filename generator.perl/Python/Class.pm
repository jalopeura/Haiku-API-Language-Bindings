use Common::Bindings;
use Python::BaseObject;

package Python::Class;
use File::Spec;
use File::Path;
use Python::Functions;
use Python::Properties;
use Python::Operators;
use Python::Constants;
use Python::Globals;
use strict;
our @ISA = qw(Binding Python::BaseObject);

my @number_methods = qw(
	nb_add
	nb_subtract
	nb_multiply
	nb_divide
	nb_remainder
	nb_divmod
	nb_power
	nb_negative
	nb_positive
	nb_absolute
	nb_nonzero
	nb_invert
	nb_lshift
	nb_rshift
	nb_and
	nb_xor
	nb_or
	nb_coerce
	nb_int
	nb_long
	nb_float
	nb_oct
	nb_hex
	
	nb_inplace_add
	nb_inplace_subtract
	nb_inplace_multiply
	nb_inplace_divide
	nb_inplace_remainder
	nb_inplace_power
	nb_inplace_lshift
	nb_inplace_rshift
	nb_inplace_and
	nb_inplace_xor
	nb_inplace_or
	
	nb_floor_divide
	nb_true_divide
	nb_inplace_floor_divide
	nb_inplace_true_divide
	
	nb_index
);

sub is_responder { 0 }

sub finalize_upgrade {
	my ($self) = @_;
	
	my @n = split /::/, $self->{python_name};
	$self->{python_name} = join('.', @n);
	if ($self->has('python_parent')) {
		$self->{python_parent}=~s/::/./g;
	}
	
	$self->{initfunc_name} = join('_', 'init', @n, 'PyType');
	$self->{pytype_name} = join('_', @n, 'PyType');
	$self->{pyobject_name} = join('_', @n, 'PyObject');
	$self->{method_table_name} = join('_', @n, 'PyMethods');
	$self->{property_table_name} = join('_', @n, 'PyProperties');
	
	if ($self->has('functions') and $self->functions->has('plains')) {
		$self->{_parent}->add_functions(delete $self->functions->{plains});
		
		unless ($self->functions->has('constructors')
			or $self->functions->has('destructor')
			or $self->functions->has('methods')
			or $self->functions->has('events')
			or $self->functions->has('statics')) {
			delete $self->{functions};
		}
	}
	
	$self->{method_table} = [];
	
	$self->propagate_value('class', $self);
	
	if ($self->has('cpp_name')) {
		$self->propagate_value('cpp_class_name', $self->cpp_name);
		$self->propagate_value('python_class_name', $self->python_name);
	}
}

sub add_method_table_entry {
	my ($self, $python_name, $function_pointer, $flags, $doc) = @_;
	push @{ $self->{method_table} }, qq({"$python_name", (PyCFunction)$function_pointer, $flags, "$doc"});
}

sub add_richcompare_block {
	my ($self, $constant, $defs, $code) = @_;
	
	$self->{richcompare_blocks} ||= [];
	push @{ $self->{richcompare_blocks} }, [ $constant, $defs, $code ];
}

sub add_as_number_op {
	my ($self, $key, $funcname) = @_;
	
	$self->{as_number_ops} ||= [];
	push @{ $self->{as_number_ops} }, [ $key, $funcname ];
}

sub generate {
	my ($self, $folder, $ext_prefix) = @_;
	
	# if there's no python name, we're just a bundle and there's nothing to
	# generate
	return unless ($self->has('python_name'));
	
	$self->open_files($folder, $ext_prefix);
	
	$self->generate_preamble;
	
	$self->generate_body;
	
	$self->generate_postamble;
	
	$self->close_files;
}

sub open_files {
	my ($self, $folder, $ext_prefix) = @_;
	
	my @subpath = split /\./, $self->python_name;
	my $filename = pop @subpath;

	my $ext_folder = File::Spec->catfile($folder, $ext_prefix, @subpath);
	
	mkpath($ext_folder);
	
	# PY file
#	my $py_filename = File::Spec->catfile($ext_folder, "$filename.py");
#	open $self->{pyh}, ">$py_filename" or die "Unable to create file '$py_filename': $!";
	
	# CC file
	my $cc_filename = File::Spec->catfile($ext_folder, "$filename.cc");
	open $self->{cch}, ">$cc_filename" or die "Unable to create file '$cc_filename': $!";
	
	$self->{cc_include} = join('/', $ext_prefix, @subpath, "$filename.cc");
	
	$self->{filename} = $filename;
}

sub generate_preamble {
	my ($self) = @_;
	
	$self->generate_py_preamble;
	$self->generate_cc_preamble;
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
	# operators
	#
	
	if ($self->has('operators')) {
		$self->operators->generate;
	}
	
	#
	# globals
	#
	
	if ($self->has('globals')) {
		$self->globals->generate;
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
	
	$self->generate_py_postamble;
	$self->generate_cc_postamble;
}

sub close_files {
	my ($self) = @_;
#	close $self->{pyh};
	close $self->{cch};
}

#
# PY-specific sections
#

sub generate_py_preamble {}	# nothing to do
sub generate_py_body {}	# nothing to do
sub generate_py_postamble {}	# nothing to do

#
# CC-specific sections
#

sub generate_cc_preamble {
	my ($self) = @_;
	
	my $python_class_name = $self->python_name;
	my $python_package_name = $self->package_name;
	
	print { $self->cch } <<TOP;
/*
 * Automatically generated file
 */

TOP
	
	if ($self->has('constants')) {
		my @n = split /\./, $python_class_name;
		$n[-1] .= 'Constants';
		my $methdefname = join('_', @n, 'PyMethods');
		print { $self->cch } <<METHODS;
// we need a module to expose the constants, and every module needs
// a methoddef, even if it's empty
static PyMethodDef ${methdefname}[] = {
	{NULL} /* Sentinel */
};
METHODS
		$self->{constants_module_method_table_name} = $methdefname;
	}
}

sub generate_cc_postamble {
	my ($self) = @_;
	
	$self->generate_default_operators;
	
	my $fh = $self->cch;
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_';
	
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my ($init_function, $dealloc_function, $parent, $parents,
		$doc, $property_table, $method_table, $richcompare, $as_number);
	
	if ($self->has('constructor_name')) {
		$init_function = $self->constructor_name;
	}
	else {
		$init_function = 0;
	}
	if ($self->has('destructor_name')) {
		$dealloc_function = $self->destructor_name;
	}
	else {
		$dealloc_function = 0;
	}
	
	# richcompare
	$richcompare = '0';
	if ($self->has('richcompare_blocks')) {
		$richcompare = $python_object_prefix . '_RichCompare';
		print $fh <<CMP;
static PyObject* $richcompare(PyObject* a, PyObject* b, int op) {
	bool retval;
	
	switch (op) {
CMP
		for my $block ($self->richcompare_blocks) {
			my ($constant, $defs, $code) = @$block;
			print $fh "\t\tcase $constant:\n";
		
			if (@$defs) {
				print $fh map { "\t\t\t$_\n"; } @$defs;
				print $fh "\t\t\t\n";
			}
			
			print $fh map { "\t\t\t$_\n"; } @$code;
			print $fh "\t\t\tbreak;\n\t\t\t\n";
		}
		
		print $fh <<CMP;
		default:
			return Py_NotImplemented;
	}
}

CMP
	}
	
	# getter/setter
	$property_table = '0';
	if ($self->has('property_table')) {
		$property_table = $self->property_table_name;
		print $fh qq(static PyGetSetDef ${property_table}[] = {\n);
		for my $def (@{ $self->{property_table} }) {
			print $fh "\t$def,\n";
		}
		print $fh "\t{NULL} /* Sentinel */\n};\n\n";
	}
	
	# methods table
	$method_table = '0';
	if ($self->has('method_table')) {
		$method_table = $self->method_table_name;
		print $fh qq(static PyMethodDef ${method_table}[] = {\n);
		for my $def (@{ $self->{method_table} }) {
			print $fh "\t$def,\n";
		}
		print $fh "\t{NULL} /* Sentinel */\n};\n\n";
	}
	
	# as_number
	$as_number = '0';
	if ($self->has('as_number_ops')) {
		$as_number = $python_object_prefix . '_AsNumber';
		my %ops;
		for my $op ($self->as_number_ops) {
			my ($key, $funcname) = @$op;
			$ops{$key} = $funcname;
		}
		
		print $fh "static PyNumberMethods $as_number = {\n\t";
		print $fh join(",\n\t", map { "/* $_ */\t" . ($ops{$_} || '0') } @number_methods);
		print $fh "\n};\n\n";
		
		$as_number =  '&' . $as_number;
	}
	
	if ($self->has('python_parent')) {
		my @p = split /\s+/, $self->{python_parent};
		for my $p (@p) {
			$p=~s/\./_/g;
			$p = '&' . $p . '_PyType';
		}
		
		if (@p > 1) {
			$parents = sprintf("PyTuple_Pack(%d, %s)", scalar(@p), join(', ', @p));
			$parent = 0;
		}
		else {
			$parent = $p[0];
			$parents = 0;
		}
	}
	else {
		$parent = 0;
		$parents = 0;
	}

	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	
	my $flags = 'Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE';
	
	# type object
	print $fh <<TYPE;
static void $self->{initfunc_name}(PyTypeObject* type) {
	type->tp_name        = "$self->{python_name}";
	type->tp_basicsize   = sizeof(${python_object_prefix}_Object);
	type->tp_dealloc     = (destructor)$dealloc_function;
	type->tp_as_number   = $as_number;
	type->tp_flags       = $flags;
	type->tp_doc         = "...";
	type->tp_richcompare = $richcompare;
	type->tp_methods     = $method_table;
	type->tp_getset      = $property_table;
	type->tp_base        = $parent;
	type->tp_init        = (initproc)$init_function;
	type->tp_alloc       = PyType_GenericAlloc;
	type->tp_new         = PyType_GenericNew;
	type->tp_bases       = $parents;
}

TYPE

=pod

	# type object
	print $fh <<TYPE;
static int $self->{initfunc_name}() {
	PyTypeObject $self->{pytype_name} = {
		PyObject_HEAD_INIT(NULL)
		0,                         /*ob_size*/
		"$self->{python_name}",    /*tp_name*/
		sizeof(${python_object_prefix}_Object), /*tp_basicsize*/
		0,                         /*tp_itemsize*/
		(destructor)$dealloc_function, /*tp_dealloc*/
		0,                         /*tp_print*/
		0,                         /*tp_getattr*/
		0,                         /*tp_setattr*/
		0,                         /*tp_compare*/
		0,                         /*tp_repr*/
		$as_number,                         /*tp_as_number*/
		0,                         /*tp_as_sequence*/
		0,                         /*tp_as_mapping*/
		0,                         /*tp_hash */
		0,                         /*tp_call*/
		0,                         /*tp_str*/
		0,                         /*tp_getattro*/
		0,                         /*tp_setattro*/
		0,                         /*tp_as_buffer*/
		$flags,                    /*tp_flags*/
		"...",                     /* tp_doc */
		0,                         /* tp_traverse */
		0,                         /* tp_clear */
		$richcompare,              /* tp_richcompare */
		0,                         /* tp_weaklistoffset */
		0,                         /* tp_iter */
		0,                         /* tp_iternext */
		$method_table,             /* tp_methods */
		0,                         /* tp_members */
		$property_table,           /* tp_getset */
		$parent,                   /* tp_base */
		0,                         /* tp_dict */
		0,                         /* tp_descr_get */
		0,                         /* tp_descr_set */
		0,                         /* tp_dictoffset */
		(initproc)$init_function,  /* tp_init */
		PyType_GenericAlloc,       /* tp_alloc */
		PyType_GenericNew,         /* tp_new */
		0,                         /* tp_free */
		0,                         /* tp_is_gc */
	    $parents                   /* tp_bases */
	};
	
	return PyType_Ready(&$self->{pytype_name});
}

TYPE

=cut

}

sub generate_default_operators {
	my ($self) = @_;
	
	$self->{richcompare_blocks} ||= [];
	
	my ($found_eq, $found_ne);
	for my $block (@{ $self->{richcompare_blocks} }) {
		if ($block->[0] eq 'Py_EQ') {
			$found_eq = 1;
		}
		elsif ($block->[0] eq 'Py_NE') {
			$found_ne = 1;
		}
	}
	
	return if ($found_eq and $found_ne);
	
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	my $pyobj_type = "${python_object_prefix}_Object";
	
	if (not $found_eq) {
		push @{ $self->{richcompare_blocks} },
			[ 'Py_EQ', [], [
				qq(retval = (($pyobj_type*)a)->cpp_object == (($pyobj_type*)b)->cpp_object;),
				qq(return Py_BuildValue("b", retval ? 1 : 0);),
			]];
	}
	
	if (not $found_ne) {
		push @{ $self->{richcompare_blocks} },
			[ 'Py_NE', [], [
				qq(retval = (($pyobj_type*)a)->cpp_object != (($pyobj_type*)b)->cpp_object;),
				qq(return Py_BuildValue("b", retval ? 1 : 0);),
			]],
	}
}

1;
