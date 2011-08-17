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

sub type_options {
	my ($self) = @_;
	my $options = {
		name => 'python_self->cpp_object->' . $self->name,
		must_not_delete => 1,
	};
	for (qw(array_length string_length max_array_length max_string_length)) {
		if ($self->has($_)) {
			$options->{$_} = $self->{$_};
		}
	}
	return $options;
}

sub arg_builder {
	my ($self, $options) = @_;
	return $self->type->arg_builder($options);
}

sub arg_parser {
	my ($self, $options) = @_;
	return $self->type->arg_parser($options);
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
	
	my $fh = $self->class->cch;
	
	my $get_fmt = $self->type->format_item;
	my $get_arg = 'py_' . $self->name;
	my $options = {
		input_name => 'python_self->cpp_object->' . $self->name,
		output_name => $get_arg,
		must_not_delete => 1,
	};
	for (qw(array_length string_length)) {
		if ($self->has($_)) {
			$options->{$_} = $self->{$_};
		}
	}
	my ($get_defs, $get_code) = $self->arg_builder($options);
	
	my $obj_return;
	if ($self->type->has('target') and my $target = $self->type->target
		and not($self->has('array_length'))) {
		(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
		unshift @$get_defs, "$objtype* $get_arg;\n";
		$obj_return = 1;
	}
	else {
		unshift @$get_defs, "PyObject* $get_arg; // from generate()";
	}
	
	print $fh qq(static PyObject* $getter_name($class_name* python_self, void* python_closure) {\n);
	print $fh map { "\t$_\n" } @$get_defs;
	print $fh map { "\t$_\n" } @$get_code;
	
	if ($obj_return) {
		print $fh qq(\treturn (PyObject*)$get_arg;\n);
	}
	else {
		print $fh qq(\treturn $get_arg;\n);
	}
	print $fh "}\n\n";
	
	my $set_fmt = $self->type->format_item;
	my $options = {
		input_name => 'value',
		output_name => 'python_self->cpp_object->' . $self->name,
		repeat => $self->repeat,
	};
	for (qw(array_length string_length)) {
		if ($self->has($_)) {
			$options->{$_} = $self->{$_};
		}
	}
	my ($set_defs, $set_code) = $self->arg_parser($options);
	print $fh qq(static int $setter_name($class_name* python_self, PyObject* value, void* closure) {\n);
	print $fh map { "\t$_\n" } @$set_defs;
	print $fh map { "\t$_\n" } @$set_code;
	print $fh "\treturn 0;\n";	# do we need error checks, or will Python raise an exception for us?
	print $fh "}\n\n";
	
	push @{ $self->class->{property_table } }, qq({ (char*)"$property_name", (getter)$getter_name, (setter)$setter_name, (char*)"<DOC>", NULL});
}

1;
