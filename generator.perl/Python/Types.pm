use Common::Types;
use Python::BaseObject;

package Python::Types;
use strict;
our @ISA = qw(Types Python::BaseObject);

# need to handle long double

# map builtin types to python tuple format items
our %builtins = (
	'char'    => 'b',
	'short'   => 'h',
	'int'     => 'i',
	'long'    => 'l',
	'unsignedchar'  => 'B',
	'unsignedshort' => 'H',
	'unsignedint'   => 'I',
	'unsignedlong'  => 'k',
	'wchar_t' => 'h',
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
	
	'responder' => 'O',
	'object'    => 'O',
	'responder_ptr' => 'O',
	'object_ptr'    => 'O',
);

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
			warn "Type '$type' mapped to unsupported builtin type '$builtin'";
			
		$type->{format_item} = $format_item;
		$type->{self_defined} = 0,
	}
}

sub register_type {
	my ($self, $name, $builtin, $target) = @_;
#print "Registering type $name/$builtin/$target\n";
	
#	$type=~s/([^\s*])*/$1 */;	# xsubpp wants this space in the typemap
	
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
		next if $seen{$cpp_type};
		$seen{$cpp_type} = 1;
		
		(my $python_type = $type->target)=~s/\./_/g;
		
		print $fh <<OBJECT;
// make a default version here so it's available early
// we'll fill in the values in another file
extern PyTypeObject ${python_type}_PyType;
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
	my ($self, $param) = @_;
	
	my $item = $self->format_item;
	my $name = $param->name;
	
	my $arg = $name;
	my (@def, @code);
	
	if ($item=~/^O/) {
		my $builtin = $self->builtin;
		
		if ($builtin eq 'bool') {
			$item = 'b';
			$arg = "($name ? 1 : 0)";
		}
		else {
			$arg = "py_$name";
			push @def, "PyObject* py_$name;";
			my $builtin = $self->builtin;
			my $target;
			
			if ($builtin eq 'char**') {
				my $count = $param->count->name;
				push @code, qq(py_$name = CharArray2PyList($name, (int)$count););
			}
			elsif ($builtin eq 'object' or $builtin eq 'responder'
				or $builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
				$target = $self->target;
				(my $objprefix = $target)=~s/\./_/g; $objprefix .= '_';
				my $objtype = $objprefix . 'Object';
				my $type_name = $objprefix . 'PyType';
				
				$def[-1] = "$objtype* $arg;";
				
				push @code,
					#qq(PyTypeObject* py_${name}_type = (PyTypeObject*)PyRun_String("$target", Py_eval_input, main_dict, main_dict);),
					#qq(py_$name = ($objtype*)py_${name}_type->tp_alloc(py_${name}_type, 0););
					qq(py_$name = ($objtype*)$type_name.tp_alloc(&$type_name, 0););
				
				if ($builtin eq 'object' or $builtin eq 'responder') {
					push @code, qq(py_$name->cpp_object = &$name;);
				}
				else {
					push @code, qq(py_$name->cpp_object = $name;);
				}
				
				if ($param->must_not_delete) {
					push @code,
						qq(// cannot delete this object; we do not own it),
						qq(py_$name->can_delete_cpp_object = false;);
				}
				else {
					push @code,
						qq(// we own this object, so we can delete it),
						qq(py_$name->can_delete_cpp_object = true;);
				}
			}
			else {
				die "Unsupported type: $name/$builtin/$target";
			}
		}
	}
	
	return ($item, $arg, \@def, \@code);
}

sub arg_parser {
	my ($self, $param) = @_;
	
	my $item = $self->format_item;
	my $name = $param->name;
	
	my $arg = $name;
	my (@def, @code);
	
	my $def = "$param->{type_name} $name";
	if ($param->has('default')) {
		$def .= " = " . $param->default;
	}
	$def .= ';';
	push @def, $def;
	
	if ($item=~/^O/) {
		$arg = "py_$name";
		push @def, "PyObject* $arg;";
		
		my $builtin = $self->builtin;
		my $target;
		if ($builtin eq 'bool') {
			push @code, qq($name = (bool)(PyObject_IsTrue($arg)););
		}
		elsif ($builtin eq 'char**') {
			my $count_name = $param->count->name;
			my $count_type = $param->count->type_name;
			push @def, "$count_type $count_name = 0;";
			push @code, qq($name = PyList2CharArray($arg, (int*)&$count_name););
		}
		elsif ($builtin eq 'object' or $builtin eq 'responder'
			or $builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
			$target = $self->target;
			(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
			
			$def[-1] = "$objtype* $arg;";
			if ($builtin eq 'object' or $builtin eq 'responder') {
				push @code, qq($name = *((($objtype*)$arg)->cpp_object););
			}
			else {
				push @code, qq($name = (($objtype*)$arg)->cpp_object;);
			}
			if ($param->must_not_delete) {
				push @code, qq((($objtype*)$arg)->can_delete_cpp_object = false;);
			}
		}
		else {
			die "Unsupported type: $param->{type}/$builtin/$target";
		}
	}
	
	return ($item, "&$arg", \@def, \@code);
}

package Python::BuiltinType;
use strict;
our @ISA = qw(Python::Type);

sub new {
	my ($class, $name, $format_item) = @_;
	my $self = bless {
		name        => $name,
		builtin     => $name,
		format_item => $format_item,
	};
	return $self;
}

1;
