use Common::Functions;
use Python::BaseObject;

package Python::Params;
use strict;
our @ISA = qw(BaseObject Python::BaseObject);

sub new {
	my ($class, @params) = @_;
	
	my $self = bless {
		_params => {},
		cpp_input => [],
		python_input => [],
		python_output => [],
		python_error => [],
	}, $class;
	
	$self->add(@params);
	
	return $self;
}

sub add {
	my ($self, @params) = @_;
	
	my @mod;
	for my $param (@params) {
		$self->{_params}{ $param->name } = $param;
		
		if ($param->isa('Return')) {
			$self->{cpp_output} = $param;
		}
		else {
			push @{ $self->{cpp_input} }, $param;
		}
		
		my $action = $param->action;
		if ($action eq 'input') {
			push @{ $self->{python_input} }, $param;
		}
		elsif ($action eq 'output') {
			push @{ $self->{python_output} }, $param;
		}
		elsif ($action eq 'error') {
			push @{ $self->{python_error} }, $param;
		}
		elsif ($action=~/^(length|count)\[(.+?)\]$/) {
			push @mod, [ $1, $2, $param ];
		}
		else {
			die "Unsupported param action '$action'";
		}
	}
	
	for my $m (@mod) {
		my ($key, $name, $param) = @$m;
		$self->{_params}{$name}{$key} = $param;	
	}
}

# as_cpp_input gives the paramaters as used in a function definition
sub as_cpp_input {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_input;
	}
	
	return \@args;
}
sub as_cpp_parent_input {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->name;
	}
	
	return \@args;
}

# as_cpp_call gives the arguments ase used in a functioncall
sub as_cpp_call {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_call;
	}
	
	return \@args;
}

sub cpp_rettype {
	my ($self) = @_;
	if ($self->has('cpp_output')) {
		return $self->cpp_output->type;
	}
	return 'void';
}

sub as_cpp_return {
	my ($self) = @_;
	
	my ($item, $arg, @defs, @code);
	if ($self->has('cpp_output') and $self->cpp_output->type ne 'void') {
		my $type = $self->types->type($self->cpp_output->type);
		return $type->arg_builder($self->cpp_output);
	}
	return 'void';
}

sub as_input_from_python {
	my ($self) = @_;
	
	my ($format, @args, @defs, @code);
	my $seen_default;
	for my $param ($self->python_input) {
		my ($fmt, $arg, $defs, $code) = $param->as_input_from_python;
		if ($param->has('default') and not $seen_default) {
			$format .= '|';
			$seen_default = 1;
		}
		$format .= "$fmt";
		push @args, $arg;
		push @defs, @$defs;
		push @code, @$code;
	}
	
	my $outargs;
	if ($format) {
		$outargs = join(', ', qq("$format"), @args);
	}
#	else {
#		$outargs = 'NULL';
#	}
	
	return ($outargs, \@defs, \@code);
}

sub as_python_error {
	my ($self) = @_;
	
	my (@defs, @code);
	for my $param ($self->python_error) {
		my $errname = $param->name;
		my $errtype = $param->type;
		my $success = $param->success;
		
		if ($param->needs_deref) {
			$errtype=~s/\*$//;
		}
		push @defs, "$errtype $errname;";
		
		my $type = $self->types->type($errtype);
		my $erritem = $type->format_item;
		
		my @n =  split /\./, $self->package_name;
		my $errvar = $n[-1] . 'Error';
		
		push @code,
			qq(if ($errname != $success) {),
			qq(	PyObject* errval = Py_BuildValue("$erritem", $errname);),
			qq(	PyErr_SetObject($errvar, errval);),
			qq(	return NULL;),
			qq(});
	}
#	ApplicationKitError
	
	return (\@defs, \@code);
}

sub as_python_call {
	my ($self) = @_;
	
	my ($format, @args, @defs, @code);
	for my $param ($self->python_input) {
		my ($fmt, $arg, $def, $code) = $param->as_python_call;
		$format .= $fmt;
		push @args, $arg;
		push @defs, @$def;
		push @code, @$code;
	}
	
	my $outargs;
	if ($format) {
		$outargs = join(', ', qq("$format"), @args);
	}
	else {
		$outargs = 'NULL';
	}
	
	return ($outargs, \@defs, \@code);
}

sub as_python_return {
	my ($self) = @_;
	
	my ($name, $pyname, @defs, @code);
	
	if ($self->has('cpp_output') and $self->cpp_output->type ne 'void') {
		my $retval = $self->cpp_output;
		$name = $retval->name;
		$pyname = "py_$name";
		my $type = $self->types->type($retval->type);
		my $item = $type->format_item;
		
		@defs = (
			qq($retval->{type} $name;),
			qq(PyObject* $pyname;),
		);
		
		if ($item=~/[ibhlBH]/) {
			@code = (
				"$name = ($type->{name})PyInt_AsLong(py_$name)"
			);
		}
		elsif ($item=~/[Ik]/) {
			@code = (
				"$name = ($type->{name})PyLong_AsLong(py_$name)"
			);
		}
		elsif ($item=~/[fd]/) {
			@code = (
				"$name = ($type->{name})PyFloat_AsDouble(py_$name)"
			);
		}
		elsif ($item=~/^O/) {
			my $builtin = $type->builtin;
			my $target;
			
			if ($builtin eq 'bool') {
				@code = (
					"$name = (bool)(PyObject_IsTrue($pyname));"
				);
			}
			elsif ($builtin eq 'char**') {
				my $count = $retval->count->name;
				@code = (
					"$name = PyList2CharArray($pyname, (int)$count);"
				);
			}
			elsif ($builtin eq 'object' or $builtin eq 'responder') {
				$target = $type->target;
				my @n = split /\./, $target;
				my $objtype = join('_', @n, 'Object');
				
				@code = (
					"$name = *((($objtype*)$pyname)->cpp_object);"
				);
			}
			elsif ($builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
				$target = $type->target;
				my @n = split /\./, $target;
				my $objtype = join('_', @n, 'Object');
				
				@code = (
					"$name = ((($objtype*)$pyname)->cpp_object);"
				);
			}
			else {
				die "Unsupported type: $retval->{type}/$builtin/$target";
			}
		}
	}
	return ($name, $pyname, \@defs, \@code);
}

package Python::Argument;
use strict;
our @ISA = qw(Python::BaseObject);

sub as_cpp_input {
	my ($self) = @_;
	my $arg = "$self->{type} $self->{name}";
	return $arg;
}

sub as_cpp_call {
	my ($self) = @_;
	my $arg = $self->name;
	if ($self->needs_deref) {
		$arg = "&$arg";
	}
	return $arg;
}

sub as_input_from_python {
	my ($self) = @_;
	
	my $type = $self->types->type($self->type);
	
	return $type->arg_parser($self);
}

sub as_python_call {
	my ($self) = @_;
	
	my $type = $self->types->type($self->type);
	
	return $type->arg_builder($self);
}

package Python::Param;
use strict;
our @ISA = qw(Param Python::Argument);

package Python::Return;
use strict;
our @ISA = qw(Return Python::Argument);

1;
