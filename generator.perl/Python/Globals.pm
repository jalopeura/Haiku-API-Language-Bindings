use Common::Globals;
use Python::BaseObject;

package Python::Globals;
use strict;
our @ISA = qw(Globals Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('globals')) {
		for my $g ($self->globals) {
			$g->generate;
		}
	}
}

package Python::Global;
use strict;
our @ISA = qw(Global Python::BaseObject);

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
	
	(my $class_name = $self->class->python_name)=~s/\./_/g;
	$class_name .= '_Object';
	my $name = $self->name;
	my $type = $self->type;
	
	my $global_name = "${class_name}_$name";
	
	my $fh = $self->class->cch;
	
	my $pyobj_name = 'py_' . $self->name;
	my $options = {
		input_name => $self->name,
		output_name => $pyobj_name,
		must_not_delete => 1,
		repeat => $self->has('repeat') ? $self->repeat : 0,
	};
	my ($defs, $code) = $self->arg_builder($options);
	print $fh qq(static PyObject* $global_name($class_name* python_dummy) {\n);
	print $fh "\tPyObject* $pyobj_name;\n";	# may need to change this for C++ objects
	print $fh map { "\t$_\n" } @$defs;
	print $fh map { "\t$_\n" } @$code;
	print $fh qq(\treturn $pyobj_name;\n);
	print $fh "}\n\n";
	
	my $doc;
	if ($self->has('doc')) {
		$doc = $self->doc;
	}
	$self->class->add_method_table_entry(
		$self->name,		# name as seen from Python
		$global_name,		# name of wrapper function
		'METH_NOARGS|METH_STATIC',		# flags
		$doc				# docs
	);
}

1;
