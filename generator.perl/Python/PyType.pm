package Python::PyType;
use Python::PyModule;
use Python::Params;
use strict;

# there's no is-a relationship in Python terms
# but this allows us to share code
our @ISA = qw(Python::PyModule);

sub new {
	my ($class, $module, $package, $binding, $types) = @_;
	my $self = $class->SUPER::new($package, $binding, $types);
	$self->{module} = $module;
	return $self;
}

sub parse_binding {
	my ($self, $binding) = @_;
	
	my @n = split /::/, $binding->target;
	
	$self->{name} = join('.', @n, $n[-1]);
	$self->{cpp_class} = $binding->{source};
	$self->{cpp_parent} = $binding->{source_inherits};
	
	$self->{python_class} = $self->{name};
	($self->{python_parent} = $binding->{target_inherits})=~s/::/./g;
	
	$self->{type} = 'object_ptr';
	
	$self->{binding} = $binding;
}

sub generate_functions {
	my ($self) = @_;
	my $binding = $self->{binding};
	
	#
	# functions
	# (constructor, destructor, object methods, object event methods,
	#    class methods)
	#
	
	my @functions;
	
	if ($binding->constructors) {
		push @functions, $binding->constructors;
	}
	if ($binding->destructor) {
		push @functions, $binding->destructor;
	}
	if ($binding->methods) {
		push @functions, $binding->methods;
	}
	if ($binding->events) {
		push @functions, $binding->events;
	}
	if ($binding->statics) {
		push @functions, $binding->statics;
	}
	
	for my $function (@functions) {
		my $params = new Python::Params($function, $self->{types});
		#$self->parse_params($function);
		$self->generate_c_function($function, $params);
	}
	
	#
	# properties
	#
	
	for my $property ($binding->properties) {
		$self->generate_c_property($property);
	}
}

sub xgenerate_c_preamble {
	my ($self) = @_;
	
	$self->SUPER::generate_c_preamble;
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_Object';
	
	print { $self->{ch} } <<TYPEOBJ;
typedef struct {
    PyObject_HEAD
    $self->{cpp_class}* cpp_object;
	bool  can_delete_cpp_object;
} $name;

TYPEOBJ
}

sub generate_c_postamble {
	my ($self) = @_;
	
	my $fh = $self->{ch};
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_';
	
	# getter/setter
	print $fh qq(static PyGetSetDef ${name}properties[] = {\n);
	for my $def (@{ $self->{property_table} }) {
		print $fh "\t$def,\n";
	}
	print $fh "\t{NULL} /* Sentinel */\n};\n\n";
	
	# methods table
	print $fh qq(static PyMethodDef ${name}methods[] = {\n);
	for my $def (@{ $self->{method_table} }) {
		print $fh "\t$def,\n";
	}
	print $fh "\t{NULL} /* Sentinel */\n};\n\n";
	
	# type object
	print $fh <<TYPE;
static PyTypeObject ${name}Type = {
	PyObject_HEAD_INIT(NULL)
	0,                         /*ob_size*/
	"$self->{name}",             /*tp_name*/
	sizeof(${name}Object),             /*tp_basicsize*/
	0,                         /*tp_itemsize*/
	(destructor)${name}DESTROY, /*tp_dealloc*/
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
	${name}methods,            /* tp_methods */
	0,                         /* tp_members */
	${name}properties,         /* tp_getset */
	0,                         /* tp_base */
	0,                         /* tp_dict */
	0,                         /* tp_descr_get */
	0,                         /* tp_descr_set */
	0,                         /* tp_dictoffset */
	0,                         /* tp_init */
	0,                         /* tp_alloc */
	${name}new,                 /* tp_new */
};

TYPE
}

1;
