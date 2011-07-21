use Common::Constants;
use Python::BaseObject;

package Python::Constants;
use File::Spec;
use File::Path;
use strict;
our @ISA = qw(Constants Python::BaseObject);

sub generate {
	my ($self, $folder, $ext_prefix) = @_;
	
	my $class = $self->class;
	$class->{constant_defs} = [];
	$class->{constant_code} = [];
	
	if ($self->has('constants')) {
		for my $c ($self->constants) {
			$c->generate;
		}
	}
}

package Python::Constant;
use strict;
our @ISA = qw(Constant Python::BaseObject);

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
	};
	if ($self->has('repeat')) {
		$options->{repeat} = $self->repeat;
	}
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

sub generate {
	my ($self) = @_;	
	
	my $class = $self->class;
	my $constant_name = $self->name;
	(my $class_name = $class->python_name)=~s/\./_/g;
	my $object_name = "${class_name}_$constant_name";
	my $module_name = $class_name . 'Constants_module';
	
#	print $fh qq(static PyObject* $getter_name($class_name* python_self, void* python_closure) {\n);
#	print $fh map { "\t$_\n" } @$get_defs;
#	print $fh map { "\t$_\n" } @$get_code;
#	print $fh qq(\treturn Py_BuildValue("$get_fmt", $get_arg);\n);
#	print $fh "}\n\n";
	
#	my ($fmt, $arg, $defs, $code) = $self->arg_builder;
	my $options = {
		input_name => $self->name,
		output_name => $object_name,
		must_not_delete => 1,
		repeat => $self->has('repeat') ? $self->repeat : 0,
	};
	my ($defs, $code) = $self->arg_builder($options);
	
#	if ($self->type->has('target')) {
#		my @ret;
#		while (@$code) {
#			my $line = shift @$code;
#			$line=~s/py\w+/$object_name/g;
#			push @ret, $line;
#		}
#		$code = \@ret;
#		pop @$defs;
#	}
#	else {
#		push @$code, qq($object_name = Py_BuildValue("$fmt", $arg););
#	}
	
#	shift @$defs;	# because constant is already defined
	push @{ $class->{constant_defs} },
		"PyObject* $object_name;",
		@$defs;
	push @{ $class->{constant_code} },
		@$code,
#		qq($object_name = Py_BuildValue("$fmt", $arg);),
		qq(Py_INCREF($object_name);),
		qq(PyModule_AddObject($module_name, "$constant_name", $object_name);),
		"";
}

1;
