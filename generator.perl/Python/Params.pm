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

sub cpp_rettype {
	my ($self) = @_;
	if ($self->has('cpp_output')) {
		return $self->cpp_output->type_name;
	}
	return 'void';
}

sub as_python_call {
	my ($self) = @_;
	
	my ($format, @args, @defs, @code);
	for my $param ($self->python_input) {
		my $pyobj_name = 'py_' . $param->name;
		my $options = {
			input_name => $param->name,
			output_name => $pyobj_name,
			must_not_delete => $param->must_not_delete,
		};
		for (qw(array_length string_length)) {
			if ($param->has($_)) {
				$options->{$_} = $param->{$_};
			}
		}
		my ($def, $code) = $param->arg_builder($options);
		$format .= $param->type->format_item;
		push @args, $pyobj_name;
		push @code, @$code;
		
		if ($param->type->has('target') and my $target = $param->type->target and
			not $param->has('array_length')
			) {
			(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
			push @defs, "$objtype* $pyobj_name; // from as_python_call()";
		}
		else {
			push @defs, "PyObject* $pyobj_name; // from as_python_call()",	# may need to fix this for C++ objects
		}
		push @defs, @$def;
	}
	
	my $outargs;
	if ($format) {
		$outargs = join(', ', qq((char*)"$format"), @args);
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
		my $type = $retval->type;
		my $item = $type->format_item;
		
		@defs = (
			qq($retval->{type_name} $name;),
			qq(PyObject* $pyname;	// from as_python_return()),
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

sub is_array_or_string {
	my ($self) = @_;
	
	if ($self->has('array_length') or
		$self->has('string_length') or
		$self->has('max_array_length') or
		$self->has('max_string_length')) {
		return 1;
	}
	
	my $type = $self->type;
	if ($type->has('array_length') or
		$type->has('string_length') or
		$type->has('max_array_length') or
		$type->has('max_string_length')) {
		return 1;
	}
	
	return undef;
}

sub type_options {
	my ($self) = @_;
	my $options = {
		name => $self->name,
		must_not_delete => $self->must_not_delete,
	};
	if ($self->has('default')) {
		$options->{default} = $self->default;
	}
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

sub as_cpp_def {
	my ($self) = @_;
	my $type = $self->type->name;
	if ($self->pass_as_pointer and $self->is_array_or_string) {
		# this might fail on null-terminated strings passed as pointers
		$type .= '*'
	}
	my $arg = "$type $self->{name}";
	if ($self->has('default')) {
		$arg .= " = $self->{default}";
		$arg=~s/SELF\./python_self->cpp_object->/;
	}
	$arg .= ';';
	return $arg;
}

sub python_error_code {
	my ($self, $int_return) = @_;
	
	my ($def, @code);
	
	my $errname = $self->name;
	my $errtype = $self->type_name;
	my $success = $self->success;
	my $badret  = $int_return ? '-1' : 'NULL';
	
	if ($self->pass_as_pointer) {
		$errtype=~s/\*$//;
	}
	$def = "$errtype $errname;";
	
	my $erritem = $self->type->format_item;
	
	my @n =  split /\./, $self->package_name;
	my $errvar = $n[-1] . 'Error';
	
	push @code,
		qq(if ($errname != $success) {),
		qq(	PyObject* errval = Py_BuildValue("$erritem", $errname);),
		qq(	PyErr_SetObject($errvar, errval);),
		qq(	return $badret;),
		qq(});
	
	return ($def, \@code);
}

sub as_cpp_arg {
	my ($self) = @_;
	my $arg = $self->name;
	if ($self->pass_as_pointer and not $self->is_array_or_string) {
		# this might fail on null-terminated strings passed as pointers
		$arg = "&$arg";
	}
	return $arg;
}

sub as_cpp_input {
	my ($self) = @_;
	my $type = $self->{type_name};
	if ($self->pass_as_pointer) {
		$type .= '*';
	}
	my $arg = "$type $self->{name}";
	return $arg;
}

package Python::Param;
use strict;
our @ISA = qw(Param Python::Argument);

package Python::Return;
use strict;
our @ISA = qw(Return Python::Argument);

# special subclass used by constructors because the python
# objects are created in a different way from the usual
package Python::ConstructorReturn;
use strict;
our @ISA = qw(Python::Return);

sub new {
	my ($class, %options) = @_;
	
	$options{base_name} = delete $options{name};
	$options{name} = $options{base_name} . '->cpp_object';
	
	my $self = bless \%options, $class;
	
	return $self;
}

sub as_cpp_def {
	my ($self) = @_;
	return "// $self->{name} already defined";
}

sub arg_builder {
	my ($self, $options) = @_;
	
	my @code = ();
	
	if ($self->is_responder) {
		push @code,
			qq(python_self->cpp_object->python_object = python_self;);
	}

	if ($self->must_not_delete) {
		push @code,
			qq(// we do not own this object, so we can't delete it),
			qq(python_self->can_delete_cpp_object = false;);
	}
	else{
		push @code,
			qq(// we own this object, so we can delete it),
			qq(python_self->can_delete_cpp_object = true;);
	}
	
	return (
		[],	# empty defs
		\@code
	);
}

1;
