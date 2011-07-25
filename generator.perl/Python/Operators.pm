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
		as_number => 'nb_negative',
		signature => 'unary',
	},
	
	'==' => { 
		name => 'eq',
		type => 'cmp',	# comparison
		richcompare => 'Py_EQ',
	},
	'!=' => { 
		name => 'ne',
		type => 'cmp',	# comparison
		richcompare => 'Py_NE',
	},
	
	'+' => { 
		name => 'add',
		type => 'math',	# mathematical
		as_number => 'nb_add',
		signature => 'binary',
	},
	'-' => { 
		name => 'sub',
		type => 'math',	# mathematical
		as_number => 'nb_subtract',
		signature => 'binary',
	},
	'&' => { 
		name => 'and',
		type => 'math',	# mathematical
		as_number => 'nb_and',
		signature => 'binary',
	},
	'|' => { 
		name => 'or',
		type => 'math',	# mathematical
		as_number => 'nb_or',
		signature => 'binary',
	},
	
	'+=' => { 
		name => 'iadd',
		type => 'mut',	# mutator
		as_number => 'nb_inplace_add',
		signature => 'binary',
	},
	'-=' => { 
		name => 'isub',
		type => 'mut',	# mutator
		as_number => 'nb_inplace_subtract',
		signature => 'binary',
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
		$rettype = "$cpp_class_name*";
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

	if ($type eq 'cmp') {
		@$defs = ();
		@$code = (
			qq(retval = *((($pyobj_type*)a)->cpp_object) $name *((($pyobj_type*)b)->cpp_object);),
			qq(return Py_BuildValue("b", retval ? 1 : 0);)
		);
	}
	else {
		unless ($type eq 'mut') {
			my $class_name = $self->class->cpp_name;
			push @$defs, "$rettype retval = new $class_name();";
		}
		
		if ($type eq 'neg') {
			push @$defs, "$pyobj_type* py_retval;";
			unshift @$code, "*retval = -(*(($pyobj_type*)a)->cpp_object);";
			push @$code, "return (PyObject*)py_retval;";
		}
		elsif ($type eq 'math') {
			push @$defs,
				"$pyobj_type* py_retval;";
			unshift @$code, "*retval = *(($pyobj_type*)a)->cpp_object $name *(($pyobj_type*)b)->cpp_object;";
			push @$code, "return (PyObject*)py_retval;";
		}
		elsif ($type eq 'mut') {
			@$code = (
				"*(($pyobj_type*)a)->cpp_object $name *(($pyobj_type*)b)->cpp_object;",
				"return (PyObject*)a;",
			);
		}
		
#		push @$defs, "$cpp_class_name object;";
	}
	
	if (my $rc_constant = $ops{$name}{richcompare}) {
		$self->class->add_richcompare_block($rc_constant, $defs, $code);
	}
	elsif (my $as_number = $ops{$name}{as_number}) {
		my $signature = $ops{$name}{signature};
		my $fh = $self->class->cch;
		
		if ($signature eq 'unary') {
			print $fh "static PyObject* $fname(PyObject* a) {\n";
		}
		elsif ($signature eq 'binary') {
			print $fh "static PyObject* $fname(PyObject* a, PyObject* b) {\n";
		}
		else {
			die "Unknown operator signature: $signature";
		}
		
		if (@$defs) {
			print $fh map { "\t$_\n"; } @$defs;
			print $fh "\t\n";
		}
		
		print $fh map { "\t$_\n"; } @$code;
		
		print $fh "}\n\n";

		if ($as_number) {
			$self->class->add_as_number_op($as_number, $fname);
		}
	}
	else {
		die "Unknown operator: $name";
	}
}

1;
