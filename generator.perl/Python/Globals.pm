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
	my ($self) = @_;
	return $self->type->arg_builder($self, $self->has('repeat'));
}

sub arg_parser {
	my ($self) = @_;
	return $self->type->arg_parser($self, $self->has('repeat'));
}

sub generate {
	my ($self) = @_;
	
	(my $class_name = $self->class->python_name)=~s/\./_/g;
	$class_name .= '_Object';
	my $name = $self->name;
	my $type = $self->type;
	
	my $global_name = "${class_name}_$name";
	
	my $fh = $self->class->cch;
	
	my ($fmt, $arg, $defs, $code) = $self->arg_builder;
#	shift @$defs;	# because property is already defined
	print $fh qq(static PyObject* $global_name($class_name* python_dummy) {\n);
	print $fh map { "\t$_\n" } @$defs;
	print $fh map { "\t$_\n" } @$code;
	print $fh qq(\treturn Py_BuildValue("$fmt", $arg);\n);
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
