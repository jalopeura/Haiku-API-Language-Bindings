use Common::Bindings;
use Python::BaseObject;

package Python::Class;
use File::Spec;
use File::Path;
use Python::Functions;
use Python::Properties;
use Python::Constants;
use strict;
our @ISA = qw(Binding Python::BaseObject);

sub is_responder { 0 }

sub finalize_upgrade {
	my ($self) = @_;
	
	my @n = split /::/, $self->{python_name};
#	my @p = split /::/, $self->{_parent}{name};
#	$self->{python_name} = join('.', @p, $n[-1]);
	$self->{python_name} = join('.', @n);
	if ($self->has('python_parent')) {
		$self->{python_parent}=~s/::/./g;
	}
	
	$self->{pytype_name} = join('_', @n, 'PyType');
	$self->{pyobject_name} = join('_', @n, 'PyObject');
	$self->{method_table_name} = join('_', @n, 'PyMethods');
	$self->{property_table_name} = join('_', @n, 'PyProperties');
	
	if ($self->has('functions') and $self->functions->has('plains')) {
		$self->{_parent}->add_functions(delete $self->functions->{plains});
		
		unless ($self->has('constructors')
			or $self->has('destructor')
			or $self->has('methods')
			or $self->has('events')
			or $self->has('statics')) {
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
	
	my $fh = $self->cch;
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_';
	
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my ($init_function, $dealloc_function, $doc, $property_table, $method_table);
	
	$init_function = "${python_object_prefix}_init";
	$dealloc_function = "${python_object_prefix}_DESTROY";
	
	if ($self->has('doc')) {
		$doc = $self->doc;
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
	
	# type object
	print $fh <<TYPE;
static PyTypeObject $self->{pytype_name} = {
	PyObject_HEAD_INIT(NULL)
	0,                         /*ob_size*/
	"$self->{python_name}",             /*tp_name*/
	sizeof(${python_object_prefix}_Object),             /*tp_basicsize*/
	0,                         /*tp_itemsize*/
	(destructor)$dealloc_function, /*tp_dealloc*/
	0,                         /*tp_print*/
	0,                         /*tp_getattr*/
	0,                         /*tp_setattr*/
	0,                         /*tp_compare*/
	0,                         /*tp_repr*/
	0,                         /*tp_as_number*/
	0,                         /*tp_as_sequence*/
	0,                         /*tp_as_mapping*/
	0,                         /*tp_hash */
	0,                         /*tp_call*/
	0,                         /*tp_str*/
	0,                         /*tp_getattro*/
	0,                         /*tp_setattro*/
	0,                         /*tp_as_buffer*/
	Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
	"...",           /* tp_doc */
	0,		               /* tp_traverse */
	0,		               /* tp_clear */
	0,		               /* tp_richcompare */
	0,		               /* tp_weaklistoffset */
	0,		               /* tp_iter */
	0,		               /* tp_iternext */
	$method_table,            /* tp_methods */
	0,                         /* tp_members */
	$property_table,         /* tp_getset */
	0,                         /* tp_base */
	0,                         /* tp_dict */
	0,                         /* tp_descr_get */
	0,                         /* tp_descr_set */
	0,                         /* tp_dictoffset */
	(initproc)$init_function,                         /* tp_init */
};

TYPE
}

1;
