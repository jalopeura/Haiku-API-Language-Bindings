package Python::Event;
use Python::Functions;
use strict;
our @ISA = qw(Event Python::Function);

sub generate {
	my ($self) = @_;
	
	if ($self->class->is_responder) {
		$self->generate_py;
		$self->generate_h;
		$self->generate_cpp;
	}
	else {
		$self->generate_cc;
	}
}

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
		cpp_name => "python_self->cpp_object->${cpp_class_name}::$self->{name}",
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
		$python_name,		# name as seen from Python
		$name,				# name of wrapper function
		'METH_VARARGS',		# flags
		$doc				# docs
	);
}

sub generate_cc_function {
	my ($self, $options) = @_;
	my $funcname = $self->class->cpp_name . '::' . $self->name;
	Python::Method::generate_cc_function($self, $options, $funcname);
}

sub generate_h {
	my ($self) = @_;
	my $name = $self->name;
	my $rettype = $self->params->cpp_rettype;
	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	
	print { $self->class->hh } <<EVENT;
		$rettype $name($inputs);
EVENT
}

sub generate_cpp {
	my ($self) = @_;
	
	my $name = $self->name;
	my $rettype = $self->params->cpp_rettype;
	my $cpp_class_name = $self->cpp_class_name;
	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	my $cpp_parent_name = $self->class->cpp_parent;
	my $parent_inputs = join(', ', @{ $self->params->as_cpp_parent_input });
	
	my $void_return = $rettype eq 'void';
	
	my $fh = $self->class->cpph;

	print $fh <<EVENT;
$rettype ${cpp_class_name}::$name($inputs) {
	if (python_object == NULL) {
		return ${cpp_parent_name}::$name($parent_inputs);
	}
	else {
EVENT
	
	my ($retname, $pyretname, $retcode);
	unless ($void_return) {
		print $fh "\t\t// for returning to caller\n";
		($retname, $pyretname, my $retdefs, $retcode) = $self->params->as_python_return;
		for my $line (@$retdefs) {
			print $fh "\t\t$line\n";
		}
		print $fh "\t\t\n";
	}
	
	my ($python_call_args, $python_call_defs, $python_call_code) = $self->params->as_python_call;
	
	if (@$python_call_defs) {
		print $fh "\t\t// defs\n";;
		for my $line (@$python_call_defs) {
			print $fh "\t\t$line\n";
		}
		print $fh "\t\t\n";
	}
	
	if (@$python_call_code) {
		print $fh "\t\t// set values\n";;
		for my $line (@$python_call_code) {
			print $fh "\t\t$line\n";
		}
		print $fh "\t\t\n";
	}
	
	if ($void_return) {
		print $fh <<EVENT;
		// call the proper method
		PyObject_CallMethod((PyObject*)python_object, (char*)"$name", $python_call_args);
EVENT
	}
	else {
		print $fh <<EVENT;
		// call the proper method
		$pyretname = PyObject_CallMethod((PyObject*)python_object, (char*)"$name", $python_call_args);
		
EVENT
	}
	
	unless ($void_return) {
		print $fh "\t\t// process return\n";;
		for my $line (@$retcode) {
			print $fh "\t\t$line\n";
		}
		print $fh "\t\t\n";
		print $fh "\t\treturn $retname;\n";
	}
		
	print $fh <<EVENT;
	}
} // ${cpp_class_name}::$name

EVENT
}

1;
