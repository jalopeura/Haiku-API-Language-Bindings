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
		func => 'unary',
		code => 'nb_negative',
	},
	
	'==' => { 
		name => 'eq',
		type => 'cmp',	# comparison
		func => 'richcompare',
		code => 'Py_EQ',
	},
	'!=' => { 
		name => 'ne',
		type => 'cmp',	# comparison
		func => 'richcompare',
		code => 'Py_NE',
	},
	
	'+' => { 
		name => 'add',
		type => 'math',	# mathematical
		func => 'binary',
		code => 'nb_add',
	},
	'-' => { 
		name => 'sub',
		type => 'math',	# mathematical
		func => 'binary',
		code => 'nb_subtract',
	},
	'&' => { 
		name => 'and',
		type => 'math',	# mathematical
		func => 'binary',
		code => 'nb_and',
	},
	'|' => { 
		name => 'or',
		type => 'math',	# mathematical
		func => 'binary',
		code => 'nb_or',
	},
	
	'+=' => { 
		name => 'iadd',
		type => 'mut',	# mutator
		func => 'binary',
		code => 'nb_inplace_add',
	},
	'-=' => { 
		name => 'isub',
		type => 'mut',	# mutator
		func => 'binary',
		code => 'nb_inplace_subtract',
	},
);

sub generate {
	my ($self) = @_;
	
	my $name = $self->name;
	
	$ops{$name} or die "Unsupported operator '$name'";
	
	my $cpp_class_name = $self->class->cpp_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	my $pyobj_type = "${python_object_prefix}_Object";
	my $type = $ops{$name}{type};
	
	my $rettype;
	if ($type eq 'neg' or $type eq 'math' or $type eq 'mut') {
		$rettype = $cpp_class_name;
	}
	elsif ($type eq 'cmp') {
		$rettype = 'bool';
	}
	
	my $defs = [];
	my $code = [];
	
	my $fh = $self->class->cch;
	
	# Comparison operators causing garbage collection problem
	if ($type eq 'cmp') {
		unshift @$code, "retval = *(($pyobj_type*)a)->cpp_object $name *(($pyobj_type*)b)->cpp_object;";
		push @$code, qq(return Py_BuildValue("b", retval ? 1 : 0););
	}
	else {
		if ($type eq 'mut') {
			@$code = (
				"*(($pyobj_type*)a)->cpp_object $name *(($pyobj_type*)b)->cpp_object;",
				"return (PyObject*)a;",
			);
		}
		else {
			my $type_obj = $self->types->type("$rettype*");
			my $options = {
				input_name => 'retval',
				output_name => 'py_retval',
			};
			($defs, $code) = $type_obj->arg_builder($options);
			push @$defs, 
				"$rettype* retval = new $rettype();",
				"$pyobj_type* py_retval;";
			
			if ($type eq 'neg') {
				unshift @$code, "*retval = -(*(($pyobj_type*)a)->cpp_object);";
				push @$code, "return (PyObject*)py_retval;";
			}
			elsif ($type eq 'math') {
				unshift @$code, "*retval = *(($pyobj_type*)a)->cpp_object $name *(($pyobj_type*)b)->cpp_object;";
				push @$code, "return (PyObject*)py_retval;";
			}
		}
	}
	
	my $func = $ops{$name}{func};
	my $functype = $ops{$name}{code};
	
	if ($func eq 'richcompare') {
		$self->class->add_richcompare_block($functype, $defs, $code);
	}
	else {
		my $mname = "__$ops{$name}{name}__";
		my $fname = $python_object_prefix . $mname;
		
		if ($func eq 'unary') {
			print $fh "static PyObject* $fname(PyObject* a) {\n";
		}
		elsif ($func eq 'binary') {
			print $fh "static PyObject* $fname(PyObject* a, PyObject* b) {\n";
		}
		else {
			die "Unknown function type '$func' (with code '$functype') for operator '$ops{$name}{name}'";
		}
		
		if (@$defs) {
			print $fh map { "\t$_\n"; } @$defs;
			print $fh "\t\n";
		}
		
		print $fh map { "\t$_\n"; } @$code;
		
		print $fh "}\n\n";
		
		$self->class->add_as_number_op($functype, $fname);
	}
}

1;
