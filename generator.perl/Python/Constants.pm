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

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->{qualified_name} = $self->{name};
	
	$self->{name}=~s/^.*::([^:]+)$/$1/;
}

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
	for (qw(array_length string_length max_array_length max_string_length)) {
		if ($self->has($_)) {
			$options->{$_} = $self->{$_};
		}
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
	
	my $class = $self->class;
	my $constant_name = $self->name;
	(my $class_name = $class->python_name)=~s/\./_/g;
	my $object_name = "${class_name}_$constant_name";
	my $module_name = $class_name . 'Constants_module';
	
	my $options = {
		input_name => $self->qualified_name,
		output_name => $object_name,
		must_not_delete => 1,
		repeat => $self->has('repeat') ? $self->repeat : 0,
	};
	my ($defs, $code) = $self->arg_builder($options);

	push @{ $class->{constant_code} },
		@$code,
		qq(Py_INCREF($object_name););
	
	if ($self->type->has('target') and my $target = $self->type->target) {
		(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
		push @{ $class->{constant_defs} }, "$objtype* $object_name;";
		push @{ $class->{constant_code} },
			qq(PyModule_AddObject($module_name, "$constant_name", (PyObject*)$object_name););
	}
	else {
		push @{ $class->{constant_defs} }, "PyObject* $object_name;";
		push @{ $class->{constant_code} },
			qq(PyModule_AddObject($module_name, "$constant_name", $object_name););
	}
	
	push @{ $class->{constant_defs} }, @$defs;
	push @{ $class->{constant_code} }, "";
}

1;
