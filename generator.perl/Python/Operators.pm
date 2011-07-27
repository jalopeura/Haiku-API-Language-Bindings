use Common::Operators;
use Python::BaseObject;

package Python::Operators;
use strict;
our @ISA = qw(Operators Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('operators')) {
		for my $g ($self->operators) {
			$g->generate;
		}
	}
}

package Python::Operator;
use strict;
our @ISA = qw(Operator Python::BaseObject);

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
		name => $self->name,
		must_not_delete => 1,
		repeat => $self->repeat,
	};
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

sub repeat {
	my ($self) = @_;
	if ($self->{repeat}) {
		return $self->{repeat};
	}
	if ($self->type->has('repeat')) {
		return $self->type->repeat;
	}
	return 0;
}

my %ops = (
	'neg' => { 
		name => 'neg',
		type => 'neg',	# negation
	},
	
	'==' => { 
		name => 'eq',
		type => 'cmp',	# comparison
	},
	'!=' => { 
		name => 'ne',
		type => 'cmp',	# comparison
	},
	
	'+' => { 
		name => 'add',
		type => 'math',	# mathematical
	},
	'-' => { 
		name => 'sub',
		type => 'math',	# mathematical
	},
	'&' => { 
		name => 'and',
		type => 'math',	# mathematical
	},
	'|' => { 
		name => 'or',
		type => 'math',	# mathematical
	},
	
	'+=' => { 
		name => 'iadd',
		type => 'mut',	# mutator
	},
	'-=' => { 
		name => 'isub',
		type => 'mut',	# mutator
	},
);

sub generate {
	my ($self) = @_;
	
	my $name = $self->name;
	
	$ops{$name} or die "Unsupported operator '$name'";
	
	my $cpp_class_name = $self->class->cpp_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	my $mname = "__$ops{$name}{name}__";
	my $fname = $python_object_prefix . $mname;
	my $pyobj_type = "${python_object_prefix}_Object";
	my $type = $ops{$name}{type};
	
	my $rettype;
	if ($type eq 'neg' or $type eq 'math' or $type eq 'mut') {
		$rettype = $cpp_class_name;
	}
	elsif ($type eq 'cmp') {
		$rettype = 'bool';
	}
	
	my $type_obj = $self->types->type($rettype);
	my $options = {
		input_name => 'retval',
		output_name => 'py_retval',
	};
	my ($defs, $code) = $type_obj->arg_builder($options);
	push @$defs, "$rettype retval;";
	
	my $fh = $self->class->cch;

	if ($type eq 'neg') {
		push @$defs, "$pyobj_type* py_retval;";
		unshift @$code, "retval = -(*python_self->cpp_object);";
		push @$code, "return (PyObject*)py_retval;";
	}
	else {
		if ($type eq 'cmp') {
			unshift @$code, "retval = *(python_self->cpp_object) $name object;";
			push @$code, "return py_retval;";
		}
		elsif ($type eq 'math') {
			unshift @$code, "retval = *(python_self->cpp_object) $name object;";
			push @$code, "return (PyObject*)py_retval;";
		}
		elsif ($type eq 'mut') {
			@$code = (
				"*(python_self->cpp_object) $name object;",
				"return (PyObject*)python_self;",
			);
		}
		
		push @$defs, "$cpp_class_name object;";
		unshift @$code,
			qq(PyArg_ParseTuple(python_args, "O", &py_object);),
			qq(object = *((($pyobj_type*)py_object)->cpp_object););
	}
	
	print $fh "static PyObject* $fname($pyobj_type* python_self, PyObject* python_args) {\n";
	
	if (@$defs) {
		print $fh map { "\t$_\n"; } @$defs;
		print $fh "\t\n";
	}
	
	print $fh map { "\t$_\n"; } @$code;
	
	print $fh "}\n\n";

=pod

${cpp_class_name}::$fname(object, swap)
	INPUT:
		$cpp_class_name object;
		IV swap;
	CODE:
OPERATOR
	
	if ($type eq 'neg') {
	}
	elsif ($type eq 'cmp') {
		print $fh "\t\tRETVAL = *THIS $name object;\n";
	}
	elsif ($type eq 'math') {
		my $type_obj = $self->types->type($cpp_class_name);
		my $converter = $type_obj->output_converter('result', 'RETVAL');
		print $fh <<CODE;
		$cpp_class_name result;
		result = *THIS $name object;
		RETVAL = newSV(0);
		$converter
CODE
	}
	elsif ($type eq 'mut') {
		my $type_obj = $self->types->type("$cpp_class_name*");
		my $converter = $type_obj->output_converter('THIS', 'RETVAL');
		print $fh <<CODE;
		*THIS $name object;
		RETVAL = newSV(0);
		$converter
CODE
	}
	
	print $fh <<OPERATOR;
	OUTPUT:
		RETVAL

OPERATOR

=cut
	
	my $doc;
	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	$self->class->add_method_table_entry(
		$mname,			# name as seen from Python
		$fname,			# name of wrapper function
		'METH_VARARGS',	# flags
		$doc			# docs
	);

}

1;
