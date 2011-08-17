package Python::Constructor;
use Python::Functions;
use strict;
our @ISA = qw(Constructor Python::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'new';
}

sub generate_cc {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	unless ($self->has('return')) {	
		$self->{return} ||= new Python::ConstructorReturn(
			name => 'python_self',
			type_name => $cpp_class_name . '*',
			action => 'output',
			types  => $self->types,
			needs_deref => 0,
			must_not_delete => $self->class->must_not_delete,
			is_responder => $self->class->is_responder
		);
		$self->{params} ||= new Perl::Params;
		$self->params->add($self->{return});
	}
	
	my %options = (
		cpp_name => "new $cpp_class_name",
		python_input => [
			'',
			'PyObject* python_args',
		],
		python_args => 'python_args',
	);
	
	if ($self->has('overload_name')) {
		$options{name} = "${python_object_prefix}_new" . $self->overload_name;
		$options{python_input}[0] = 'PyTypeObject* python_type';
		
		$options{predefs} = [
			qq(${python_object_prefix}_Object* python_self;),
		];
		$options{precode} = [
			qq(python_self = (${python_object_prefix}_Object*)python_type->tp_alloc(python_type, 0);),
		];
		
		my $doc;
		if ($self->has('doc')) {
			$doc = $self->doc;
		}
		$self->class->add_method_table_entry(
			$self->overload_name,	# name as seen from Python
			$options{name},		# name of wrapper function
			'METH_VARARGS|METH_CLASS',	# flags
			$doc					# docs
		);
	}
	else {
		$options{name} = "${python_object_prefix}_init";
		$options{python_input}[0] = "${python_object_prefix}_Object* python_self";
		$options{python_input}[2] = 'PyObject* python_kwds';	# __init__ always takes keywords, even though we don't do anything with them yet
		$options{rettype} = 'int';
		$options{comment} = <<COMMENT;
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
		
		$options{precode} = [
			qq(// don't let python code call us a second time),
			qq(if (python_self->cpp_object != NULL)),
			qq(	return -1;),
		];
		
		$self->class->{constructor_name} = $options{name};
	}
	
	$self->SUPER::generate_cc(%options);
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
