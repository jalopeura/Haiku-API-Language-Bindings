# this package contains methods for upgrading some standard objects
# to Python-specific objects
package Python::BaseObject;
use strict;

my %class_map = (
	Bindings => {
		key   => 'package',
		class => 'Python::Package',
		attr_map => {
			name => 'name',
			version => 'version',
		},
	},
	Binding => {
		key   => 'classes',
		class => 'Python::Class',
		attr_map => {
			source  => 'cpp_name',
			target  => 'python_name',
			'source-inherits' => 'cpp_parent',
			'target-inherits' => 'python_parent',
			'must-not-delete' => 'must_not_delete',
		},
	},
	
	Bundle => {
		key   => 'bundle',
		class => 'Python::Bundle',
	},
	BundledBindings => {
		key   => 'package',
		class => 'Python::Package',
		attr_map => {},
	},
	
	Functions => {
		key   => 'functions',
		class => 'Python::Functions',
	},
	Constructor => {
		key   => 'constructors',
		class => 'Python::Constructor',
		attr_map => {
			'overload-name'  => 'overload_name',
		},
	},
	Destructor => {
		key   => 'destructor',
		class => 'Python::Destructor',
	},
	Method => {
		key   => 'methods',
		class => 'Python::Method',
		attr_map => {
			name => 'name',
			'overload-name'  => 'overload_name',
		},
	},
	Event => {
		key   => 'events',
		class => 'Python::Event',
		attr_map => {
			name => 'name',
			'overload-name'  => 'overload_name',
		},
	},
	Static => {
		key   => 'statics',
		class => 'Python::Static',
		attr_map => {
			name => 'name',
			'overload-name'  => 'overload_name',
		},
	},
	Plain => {
		key   => 'plains',
		class => 'Python::Plain',
		attr_map => {
			name => 'name',
			'overload-name'  => 'overload_name',
		},
	},
	Param => {
		key   => 'params',
		class => 'Python::Param',
		attr_map => {
			type    => 'type_name',
			'array-length' => 'array_length',
			'string-length' => 'string_length',
#			'max-array-length' => 'max_array_length',
			'max-string-length' => 'max_string_length',
			'pass-as-pointer' => 'pass_as_pointer',
			'must-not-delete' => 'must_not_delete',
		},
	},
	Return => {
		key   => 'return',
		class => 'Python::Return',
		attr_map => {
			type    => 'type_name',
			'array-length' => 'array_length',
			'string-length' => 'string_length',
#			'max-array-length' => 'max_array_length',
			'max-string-length' => 'max_string_length',
			'pass-as-pointer' => 'pass_as_pointer',
			'must-not-delete' => 'must_not_delete',
		},
	},
	
	Properties => {
		key   => 'properties',
		class => 'Python::Properties',
	},
	Property   => {
		key   => 'properties',
		class => 'Python::Property',
		attr_map => {
			type    => 'type_name',
			'array-length' => 'array_length',
			'string-length' => 'string_length',
#			'max-array-length' => 'max_array_length',
			'max-string-length' => 'max_string_length',
			'pass-as-pointer' => 'pass_as_pointer',
		},
	},
	
	Operators => {
		key   => 'operators',
		class => 'Python::Operators',
	},
	Operator   => {
		key   => 'operators',
		class => 'Python::Operator',
		attr_map => {},
	},
	
	Constants => {
		key   => 'constants',
		class => 'Python::Constants',
	},
	Constant  => {
		key   => 'constants',
		class => 'Python::Constant',
		attr_map => {
			type    => 'type_name',
			'array-length' => 'array_length',
			'string-length' => 'string_length',
#			'max-array-length' => 'max_array_length',
			'max-string-length' => 'max_string_length',
		},
	},
	
	Globals => {
		key   => 'globals',
		class => 'Python::Globals',
	},
	Global  => {
		key   => 'globals',
		class => 'Python::Global',
		attr_map => {
			type    => 'type_name',
			'array-length' => 'array_length',
			'string-length' => 'string_length',
#			'max-array-length' => 'max_array_length',
			'max-string-length' => 'max_string_length',
		},
	},
	
	Types => {
		key   => 'types',
		class => 'Python::Types',
	},
	Type => {
		key   => 'types',
		class => 'Python::Type',
		attr_map => {
			'array-length' => 'array_length',
			'string-length' => 'string_length',
#			'max-array-length' => 'max_array_length',
			'max-string-length' => 'max_string_length',
		},
	},
	
	Include => {
		key   => 'include',
		class => 'Python::Include',
	},
	File => {
		key   => 'files',
		class => 'Python::File',
		attr_map => {},
	},
	
	Link => {
		key   => 'link',
		class => 'Python::Link',
	},
	Lib  => {
		key   => 'libs',
		class => 'Python::Lib',
		attr_map => {},
	},
);

sub finalize_upgrade {}

# upgrade handle one or multiple objects
sub upgrade {
	my ($class, $prefix, @objects) = @_;
	
	if ($#objects == 0) {
		return $class->_upgrade($prefix, $objects[0]);
	}
	
	my @ret;
	for my $object (@objects) {
		push @ret, $class->_upgrade($prefix, $object);
	}
	return @ret;
}

# _upgrade handles a single object
sub _upgrade {
	my ($class, $prefix, $object) = @_;
	
	my $new = bless { %$object }, $class;
	$object->{_upgraded_to} = $new;
	
	my $entry = get_map_entry($prefix, $object);
	my @a = $new->_attributes;
	for my $attr (@a) {
		if (exists $new->{$attr} and my $new_key = $entry->{attr_map}{$attr}) {
			$new->{$new_key} = delete $new->{$attr};
		}
	}
	
	my %c = $new->_children;
	my @c = map { $c{$_}{key} } keys %c;
	for my $k (@c) {
		my $c = delete $new->{$k};
		next unless $c;
		
		if (ref($c) eq 'ARRAY') {
			if (@$c) {
				my $child_entry = get_map_entry($prefix, $c->[0]);
				my $child_class = $child_entry->{class};
				my $key = $child_entry->{key};
				$new->{$key} = [ $child_class->upgrade($prefix, @$c) ];
			}
		}
		else {
			my $child_entry = get_map_entry($prefix, $c);
			my $child_class = $child_entry->{class};
			my $key = $child_entry->{key};
			$new->{$key} = $child_class->upgrade($prefix, $c);
		}
	}
	
	for my $k (keys %$new) {
		next unless $k=~/^_/;
		delete $new->{$k};
	}
	$new->{_upgraded_from} = $object;
	if ($object->{_parent}) {
		$new->{_parent} = $object->{_parent}{_upgraded_to} || 'Lost in translation';
	}
	
	$new->finalize_upgrade;
	
	return $new;
}

sub get_map_entry {
	my ($prefix, $object) = @_;
	
	my $class = ref $object;
	$class=~s/^${prefix}:://;	# drop type prefix
	my $entry = $class_map{$class} or die "No class mapping for (${prefix}::)$class ($object)";
	return $entry;
}

# has() (defined in BaseObject) tells you whether the object has a field
# had() instead tells you whether it had it prior to upgrading
sub had {
	my ($self, $key) = @_;
	return $self->{_upgraded_from}->has($key);
}

sub replace_value {
	my ($self, $key, $value, %options) = @_;
	
	for my $k (keys %{ $self }) {
		next if $k=~/^_/;
		my $c = $self->{$k};
		next unless $c;
		next unless ref($c);
		
		if (ref($c) eq 'ARRAY') {
			for my $e (@$c) {
				next unless $e->{$key};
				next if $e->{$key} == $value;	# won't work on strings
				$e->{$key} = $value;
				$e->replace_value($key, $value);
			}
		}
		else {
			if ($c->{$key}) {
				$c->{$key} = $value;
				next if $c->{$key} == $value;	# won't work on strings
				$c->replace_value($key, $value);
			}
		}
	}
	
}

sub propagate_value {
	my ($self, $key, $value, %options) = @_;
	
	for my $k (keys %{ $self }) {
		next if $k=~/^_/;
		my $c = $self->{$k};
		next unless $c;
		next unless ref($c);
		
		if (ref($c) eq 'ARRAY') {
			for my $e (@$c) {
				unless ($e->{$key}) {
					$e->{$key} = $value;
					$e->propagate_value($key, $value, %options);
				}
			}
		}
		else {
			unless ($c->{$key}) {
				$c->{$key} = $value;
				$c->propagate_value($key, $value, %options);
			}
		}
	}
}

sub generate {
	my ($self) = @_;
	my $class = ref($self);
	warn "No generate() method defined for class $class ($self)";
}

1;
