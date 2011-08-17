use Common::Types;
use Python::BaseObject;

package Python::Types;
use strict;
our @ISA = qw(Types Python::BaseObject);

use constant ENUM_TYPE => 'int';

# need to handle long double

# map builtin types to python tuple format items
our %builtins = (
	'char'    => 'O',
	'intchar' => 'b',
	'short'   => 'h',
	'int'     => 'i',
	'long'    => 'l',
	'unsignedchar'  => 'B',
	'unsignedshort' => 'H',
	'unsignedint'   => 'I',
	'unsignedlong'  => 'k',
	'wchar_t' => 'O',
	'float'   => 'f',
	'double'  => 'd',
	'longdouble'    => 'd',
	'bool'    => 'O',
	'char*'   => 's',
	'unsignedchar*' => 's',
	'constchar*'    => 's',
	'wchar_t*'      => 'u',
	'char**'  => 'O',
	'void*'   => 'O',
	'constvoid*'   => 's',
	'void'    => 'O',	# should only be used with pass-as-pointer
	
	'responder' => 'O',
	'object'    => 'O',
	'responder_ptr' => 'O',
	'object_ptr'    => 'O',
);
#$builtins{enum} ||= $builtins{ENUM_TYPE};	# why doesn't this work?
my $k = ENUM_TYPE;
$builtins{enum} ||= $builtins{$k};

sub create_empty {
	my ($class) = @_;
	return bless { types => [] }, $class;
}

sub finalize_upgrade {
	my ($self) = @_;
	$self->{_typemap} = {};
	$self->{types} ||= [];
	for my $type ($self->types) {
		my $name = $type->name;
		my $builtin = $type->builtin;
		$self->verify_builtin($name, $builtin);
		$self->{_typemap}{$name} = $type;
		
		$builtin=~s/ //g;
		my $format_item = $builtins{$builtin} or
			warn "Type '$name' mapped to unsupported builtin type '$builtin'";
			
		$type->{format_item} = $format_item;
		$type->{self_defined} = 0,
	}
}

sub register_type {
	my ($self, $name, $builtin, $target) = @_;
	
	# don't register an already registered type
	if (my $type = $self->{_typemap}{$name}) {
		# but warn if mapped to something different
		if ($type->builtin ne $builtin) {
			warn "Type '$name' already mapped to '$type->{builtin}'; cannot remap to '$builtin'";
		}
		return;
	}
	
	my $type = bless {
		name => $name,
		builtin => $builtin,
		self_defined => 1,
	}, 'Python::Type';
	
	if ($target) {
		$type->{target} = $target;
	}
	
	$builtin=~s/ //g;
	my $format_item = $builtins{$builtin} or
		warn "Type '$type' mapped to unsupported builtin type '$builtin'";
		
	$type->{format_item} = $format_item;
	
	$self->{_typemap}{$name} = $type;
	push @{ $self->{types} }, $type;
}

sub verify_builtin {
	my ($self, $type, $builtin) = @_;
	(my $key = $builtin)=~s/\s//g;
}

sub registered_type_count {
	my ($self) = @_;
	if ($self->{types}) {
		my $c = $#{ $self->{types} } + 1;
		return $c;
	}
	return 0;
}

sub type {
	my ($self, $name) = @_;
	return $self->{_typemap}{$name} if $self->{_typemap}{$name};
	
	# copy base types for const types
	if ($name=~/^const\s/) {
		(my $basename = $name)=~s/^const\s+//;
		if (my $type = $self->{_typemap}{$basename}) {
			my $target;
			if ($type->has('target')) {
				$target = $type->target;
			}
			$self->register_type($name, $type->builtin, $target);
			
			if (my $new_type = $self->{_typemap}{$name}) {			
				for my $x (qw(
					array_length max_array_length
					string_length max_string_length
				)) {
					next unless $type->has($x);
					$new_type->{$x} = $type->{$x};
				}
				return $new_type;
			}
		}
		
		(my $k = $basename)=~s/ //g;
		if ($builtins{$k}) {
			return new Python::BuiltinType($name, $builtins{$k}, $basename);
		}
	}
	
	(my $k = $name)=~s/ //g;
	if ($builtins{$k}) {
		return new Python::BuiltinType($name, $builtins{$k});
	}
	
	die "Unrecognized type '$name'";
}

sub write_object_types {
	my ($self, $fh) = @_;
	
	my %seen;
	for my $type (@{ $self->{types} }) {
		next unless $type->has('target') and $type->target;
		(my $cpp_type = $type->name)=~s/\*$//;
		$cpp_type=~s/^const\s+//;
		next if $seen{$cpp_type};
		$seen{$cpp_type} = 1;
		
		(my $python_type = $type->target)=~s/\./_/g;
		
		print $fh <<OBJECT;
// make a default version here so it's available early
// we'll fill in the values in another file
static PyTypeObject ${python_type}_PyType = { PyObject_HEAD_INIT(NULL) };
typedef struct {
    PyObject_HEAD
    $cpp_type* cpp_object;
	bool  can_delete_cpp_object;
} ${python_type}_Object;

OBJECT
	}
}

sub foreign_objects {
	my ($self) = @_;
	
	my (%seen, @ret);
	for my $type (@{ $self->{types} }) {
		next unless $type->has('target') and $type->target;
		(my $cpp_type = $type->name)=~s/\*$//;
		next if $seen{$cpp_type};
		$seen{$cpp_type} = 1;
		
		unless ($type->self_defined) {
			push @ret, $type;
		}
	}
	
	return @ret;
}

package Python::Type;
use strict;
our @ISA = qw(Type Python::BaseObject);

sub finalize_upgrade {
	my ($self) = @_;
	$self->{target}=~s/::/./g;
	$self->{target_inherits}=~s/::/./g;
}

sub arg_builder {
	my ($self, $options) = @_;
	
	my $builtin = $self->builtin;
	if ($options->{array_length}) {
		return $self->array_arg_builder($options);
	}
	
	my $len =  $options->{string_length};
	if (not $len and $self->has('string_length')) {
		$len = $self->string_length;
	}
	
	# strings with lengths need special processing
	if ($len and $len ne 'null-terminated') {
		$len=~s/SELF\./python_self->cpp_object->/;
		(my $base = $self->{name})=~s/const\s+//;
		
		my $input = $options->{input_name};
		unless ($base=~/\*$/) {
			$input = "&$input"
		}
		
		return (
			[],	# empty defs
			[ qq($options->{output_name} = Py_BuildValue("s#", $input, $len);) ]
		);
	}
	
	my $maxlen =  $options->{max_string_length};
	if (not $maxlen and $self->has('max_string_length')) {
		$maxlen = $self->max_string_length;
	}
	
	# strings with maximum length (but can be null-terminated)
	if ($maxlen) {
		$maxlen=~s/SELF\./python_self->cpp_object->/;
		(my $base = $self->{name})=~s/const\s+//;
		
		my $py_length = $options->{output_name} . '_length';
		
		my $input = $options->{input_name};
		unless ($base=~/\*$/) {
			$input = "&$input"
		}
		
		return (
			[ "Py_ssize_t $py_length;" ],
			[
				qq($options->{output_name} = Py_BuildValue("s", $input);	// 's' instead of 's#' lets Python calculate length),
				'',
				qq($py_length = PyString_Size($options->{output_name});),
				qq(if ($py_length > $maxlen) {),
				qq(\t$py_length = $maxlen;),
				qq(\t_PyString_Resize(&$options->{output_name}, $py_length);),
				qq(}),
				'',
			],
		);
	}
	
	my $item = $self->format_item;
	my $type_name = $self->name;
	
	if ($item=~/[ibhlBHIkfds]/) {
		return (
			[],	# empty defs
			[ qq($options->{output_name} = Py_BuildValue("$item", $options->{input_name});) ]
		);
	}
	
	my $target;
	
	if ($item=~/^O/) {
		if ($builtin eq 'bool') {
			return (
				[],	# empty defs
				[ qq($options->{output_name} = Py_BuildValue("b", ($options->{input_name} ? 1 : 0));) ]
			);
		}
		
		if ($builtin eq 'char' or $builtin eq 'wchar_t') {
			my $length = $options->{repeat} || 1;
			return (
				[],	# empty defs
				[ qq($options->{output_name} = Char2PyString(&$options->{input_name}, $length, sizeof($builtin));) ]
			);
		}
		
		if ($builtin eq 'char**') {
			my $count_name = $options->{count}{name};
			my @defs = ();
			return (
				\@defs,
				[ qq($options->{output_name} = CharArray2PyList($options->{input_name}, (int)$count_name);) ]
			);
		}
		
		if ($builtin eq 'object' or $builtin eq 'responder'
			or $builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
			$target = $self->target;
			(my $objprefix = $target)=~s/\./_/g; $objprefix .= '_';
			my $objtype = $objprefix . 'Object';
			my $type_name = $objprefix . 'PyType';
			
			my @defs = ();
			my @code = ();
			
			push @code,
				qq($options->{output_name} = ($objtype*)$type_name.tp_alloc(&$type_name, 0););
			
			(my $type_name = $self->name)=~s/^const\s+//;
			if ($builtin eq 'object' or $builtin eq 'responder') {
				push @code, qq($options->{output_name}->cpp_object = ($type_name*)&$options->{input_name};);
			}
			else {
				push @code, qq($options->{output_name}->cpp_object = ($type_name)$options->{input_name};);
			}
			
			if ($options->{must_not_delete}) {
				push @code,
					qq(// cannot delete this object; we do not own it),
					qq($options->{output_name}->can_delete_cpp_object = false;);
			}
			else {
				push @code,
					qq(// we own this object, so we can delete it),
					qq($options->{output_name}->can_delete_cpp_object = true;);
			}
			
			return (
				\@defs,
				\@code,
			);
		}
		
		# this is not what we really want to do with void*, but this prevents a fatal
		# error, which we want to ignore until we're ready to support void*
		if ($builtin eq 'void*') {
			return (
				[],	# empty defs
				[ qq($options->{output_name} = Py_BuildValue("I", (int)$options->{input_name});) ]
			);
		}
	}
	
	die "Unsupported type: $self->{name}/$builtin/$target";
}

sub array_arg_builder {
	my ($self, $options) = @_;
	
	my $item = 'O';
	my $arg = $options->{output_name};
	my $count = delete $options->{array_length};
	# I should make these constants instead of hard-coding them here
	$count=~s/SELF\./python_self->cpp_object->/;
	
	$options->{input_name} .= '[i]';
	$options->{output_name} .= '_element';
	my ($element_defs, $element_code) = $self->arg_builder($options);
	
	my (@defs, $cast_element);
	if ($self->has('target') and my $target = $self->target) {
		(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
		@defs = ("$objtype* $options->{output_name};	// from array_arg_builder");
		$cast_element = "(PyObject*)";
	}
	else {
		@defs = ("PyObject* $options->{output_name};	// from array_arg_builder");
	}
	
	my @code = (
		qq($arg = PyList_New(0);),
		qq(for (int i = 0; i < $count; i++) {),
		map( { "\t$_" } @$element_defs),
		map( { "\t$_" } @$element_code),
		qq(\tPyList_Append($arg, $cast_element$options->{output_name});),
		'}',
	);
	
	return (\@defs, \@code);
}

sub arg_parser {
	my ($self, $options) = @_;
	
	my $builtin = $self->builtin;
	if ($options->{array_length}) {
		return $self->array_arg_parser($options);
	}
	
	my $len =  $options->{string_length};
	if (not $len and $self->has('string_length')) {
		$len = $self->string_length;
	}
	
	# for input from Python, treat max length as simple length
	# (this will be a problem in Python code passes in a too-long string)
	if (not $len) {
		$len = $options->{max_string_length};
		if (not $len and $self->has('max_string_length')) {
			$len = $self->max_string_length;
		}
	}
	
	# strings with lengths need special processing
	if ($len and $len ne 'null-terminated') {
		$len=~s/SELF\./python_self->cpp_object->/;
		if ($self->{name}=~/\*$/) {
			if ($options->{set_string_length}) {
				my $cast;
				if ($self->{name} ne 'char*') {
					$cast = "(char**)";
				}
				return (
					[],	# empty defs
					[ qq(PyString_AsStringAndSize($options->{input_name}, $cast&$options->{output_name}, (Py_ssize_t*)&$len);) ]
				);
			}
			else {
				return (
					[],	# empty defs
					[ qq($options->{output_name} = PyString_AsString($options->{input_name});) ]
				);
			}
		}
		
		if ($options->{set_string_length}) {
			return (
				[ "char* buffer;" ],	# defs
				[
					
					qq(buffer = (char*)malloc(0xffff);	// should be big enough for most purposes),
					qq(PyString_AsStringAndSize($options->{input_name}, &buffer, (Py_ssize_t*)&$len);),
					qq(memcpy((void*)&$options->{output_name}, (void*)buffer, $len);),
					qq(free(buffer);),
				]
			);
		}
		else {
			return (
				[],	# empty defs
				[ qq(memcpy((void*)&$options->{output_name}, (void*)PyString_AsString($options->{input_name}), $len);) ]
			);
		}
	}
	
	my $item = $self->format_item;
	my $type_name = $self->name;
	
	if ($item=~/[ibhlBH]/) {
		return (
			[],	# empty defs
			[ "$options->{output_name} = ($type_name)PyInt_AsLong($options->{input_name});" ]
		);
	}
	
	if ($item=~/[Ik]/) {
		return (
			[],	# empty defs
			[ "$options->{output_name} = ($type_name)PyLong_AsLong($options->{input_name});" ]
		);
	}
	
	if ($item=~/[fd]/) {
		return (
			[],	# empty defs
			[ "$options->{output_name} = ($type_name)PyFloat_AsDouble($options->{input_name});" ]
		);
	}
	
	if ($item=~/[s]/) {
		return (
			[],	# empty defs
			[ "$options->{output_name} = ($type_name)PyString_AsString($options->{input_name});" ]
		);
	}
	
	my $target;
	
	if ($item=~/^O/) {		
		if ($builtin eq 'bool') {
			return (
				[],	# empty defs
				[ "$options->{output_name} = (bool)(PyObject_IsTrue($options->{input_name}));" ]
			);
		}
		
		if ($builtin eq 'char' or $builtin eq 'wchar_t') {
			my $length = $options->{repeat} || 1;
			return (
				[],	# empty defs
				[ "PyString2Char($options->{input_name}, &$options->{output_name}, $length, sizeof($builtin));" ]
			);
		}
		
		if ($builtin eq 'char**') {
			my $count_name = $options->{count}->name;
			my @defs = ();
			if ($options->{count}->has('type_name')) {
				my $count_type = $options->{count}->type_name;
				push @defs, "$count_type $count_name = 0;";
			}
			return (
				\@defs,
				[ "$options->{output_name} = PyList2CharArray($options->{input_name}, (int*)&$count_name); // from arg_parser()" ],
			);
		}
		
		if ($builtin eq 'object' or $builtin eq 'responder'
			or $builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
			$target = $self->target;
			(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
			
			my @defs = ();
			my @code = ();
			
			push @code, "if ($options->{input_name} != NULL) {";
			if ($builtin eq 'object' or $builtin eq 'responder') {
				push @code, qq(\tmemcpy((void*)&$options->{output_name}, (void*)(($objtype*)$options->{input_name})->cpp_object, sizeof($self->{name})););
			}
			else {
				push @code, qq(\t$options->{output_name} = (($objtype*)$options->{input_name})->cpp_object;);
			}
			if ($options->{must_not_delete}) {
				push @code, qq(\t(($objtype*)$options->{input_name})->can_delete_cpp_object = false;);
			}
			push @code, '}';
			
			return (
				\@defs,
				\@code,
			);
		}
	}
	
	die "Unsupported type: $self->{name}/$builtin/$target";
}

sub array_arg_parser {
	my ($self, $options) = @_;
	
	my $item = 'O';
	my $arg = $options->{input_name};
	my $count = delete $options->{array_length};
	# I should make these constants instead of hard-coding them here
	$count=~s/SELF\./python_self->cpp_object->/;
	
	$options->{input_name} .= '_element';
	$options->{output_name} .= '[i]';
	my ($element_defs, $element_code) = $self->arg_parser($options);
	my $none = $self->{name}=~/\*$/ ? 'NULL' : 0;
	$none or do {
		# an object but not via a pointer
		if ($self->has('target')) {
			undef $none;
		}
	};
	
	my @defs = ("PyObject* $options->{input_name};	// from array_arg_parser()");
	my @code;
	
	# non-constant lengths
	if ($options->{set_array_length}) {
		push @code, "$count = PyList_Size($arg);";
	}

	# malloc if necessary
	if ($options->{need_malloc}) {
		# calling code should not pass 'need_malloc' unless using a pointer (type*)
		# if using an array (type[]), calling code shouldn't need malloc
		(my $base = $self->{name})=~s/const\s+//;
		push @code, "OUT = (TYPE*)malloc($count * sizeof(TYPE));";
	}
	
	push @code, (
		qq(for (int i = 0; i < $count; i++) {),
		map( { "\t$_ // element code" } @$element_defs),
		qq(\t$options->{input_name} = PyList_GetItem($arg, i);),
		qq(\tif ($options->{input_name} == NULL) {),
	);
	
	if (defined $none) {
		push @code, qq(\t\t$options->{output_name} = $none;);
	}
	else {
		push @code,
			qq(\t\t// should be setting this to some default),
			qq(\t\t// but neither 0 nor NULL is right);
	}
	
	push @code, (
		qq(\t\tcontinue;),
		"\t}",
		map( { "\t$_ // element code" } @$element_code),
		'}',
	);
	
	return (\@defs, \@code);
}

package Python::BuiltinType;
use strict;
our @ISA = qw(Python::Type);

sub new {
	my ($class, $name, $format_item) = @_;
	(my $builtin = $name)=~s/const\s+//;	# allows for const versions of builtins
	my $self = bless {
		name        => $name,
		builtin     => $builtin,
		format_item => $format_item,
	};
	return $self;
}

1;
