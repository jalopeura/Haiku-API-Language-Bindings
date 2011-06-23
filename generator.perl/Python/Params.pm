package Python::Params;
use strict;

sub new {
	my ($class, $function, $types) = @_;
	
	my $self = bless {
		types => $types,
		params => {},
		cpp_inputs => [],
		cpp_output => undef,
		python_inputs => [],
		python_outputs => [],
		python_errors => [],
		params => {},
	}, $class;
	
	my @params;
	push @params, $function->returns;
	for my $params ($function->params_collection) {
		push @params, $params->params;
	}
	$self->add(@params);
	
	return $self;
}

sub add {
	my ($self, @params) = @_;
	for my $p (@params) {
		my $name;
		$name = $p->name or do {
			$name = $p->{name} = 'retval';
		};
		$self->{params}{$name} ||= Python::Param->new($p, $self->{types});
		my $param = $self->{params}{$name};
		
		# if another param holds the count or length of this param, and that
		# other param was parsed first, this param may have been created
		# empty, so we fix that here
		$param->{param} or $param->setparam($p);
		
		# c++ parameters
		if ($p->isa('Return')) {
			$param->{action} ||= 'output';
			$self->{cpp_output} = $param;
			push @{ $self->{python_outputs} }, $param;
		}
		else {
			push @{ $self->{cpp_inputs} }, $param;
			
			# python parameters
			my $action = $p->{action};
			if ($action eq 'input') {
				push @{ $self->{python_inputs} }, $param;
			}
			elsif ($action eq 'output') {
				push @{ $self->{python_outputs} }, $param;
			}
			elsif ($action eq 'error') {
				push @{ $self->{python_errors} }, $param;
			}
			elsif ($action=~/^(length|count)\[(.+?)\]$/) {
				my $key = $1;
				my $ref = $2;
				$self->{params}{$ref} ||= Python::Param->new(undef, $self->{types});
				$self->{params}{$ref}->setattr($key, $param);
			}
			else {
				die "Unknown action in params: $action ($p)" . join(':::', %$p);
			}
		}
	}
}

sub cpp_inputs {
	my ($self) = @_;
	return $self->{cpp_inputs};
}

sub cpp_output {
	my ($self) = @_;
	return $self->{cpp_output};
}

sub python_inputs {
	my ($self) = @_;
	return $self->{python_inputs};
}

sub python_outputs {
	my ($self) = @_;
	return $self->{python_outputs};
}

sub python_errors {
	my ($self) = @_;
	return $self->{python_errors};
}

package Python::Param;
use Carp;
use strict;

sub new {
	my ($class, $param, $types) = @_;
	
#print join(':::', $param, %$param),"\n";
	my $self = bless {
		types => $types,
	}, $class;
	$self->setparam($param) if $param;
	return $self;
}

sub setparam {
	my ($self, $param) = @_;
	$self->{name} = $param->name;
	$self->{param} = $param;
}

sub setattr {
	my ($self, $attr, $param) = @_;
	$self->{$attr} = $param;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub as_cpp {
	my ($self, $action) = @_;
	
	unless ($self->{cpp_input}) {
		my $param = $self->{param};
		my %ret;
		
		if ($param->isa('Return') and
			($param->{type} eq 'void' or not $param->{type})
			) {
			$self->{cpp_input} = {
				type => 'void',
			};
			return $self->{cpp_input};
		}
		
		# name as it should be passed to the c++ function/method
		$ret{name} = $param->name;
		$ret{type} = my $type = $param->type;
		if ($param->{deref}) {
			$ret{name} = '&' . $ret{name};
			$type=~s/\*$//;
		}
		
		# define the c++ var
		$ret{definition} = "$type $param->{name}";
		if ($param->{default}) {
			$ret{definition} .= " = $param->{default}";
			$ret{is_optional} = 1;
		}
		$ret{funcdef_definition} = "$param->{type} $param->{name}";
		
		if ($action eq 'output') {
			$ret{return_name} = "py_$ret{name}";
			
			my $item = $self->{types}->get_format_item($param->{type});
			if ($item=~/[ibhlBH]/) {
				$ret{return_code} = [
					"$ret{name} = ($param->{type})PyInt_AsLong(py_$ret{name})"
				];
			}
			elsif ($item=~/[Ik]/) {
				$ret{return_code} = [
					"$ret{name} = ($param->{type})PyLong_AsLong(py_$ret{name})"
				];
			}
			elsif ($item=~/[fd]/) {
				$ret{return_code} = [
					"$ret{name} = ($param->{type})PyFloat_AsDouble(py_$ret{name})"
				];
			}
			elsif ($item=~/^O/) {
				my ($builtin, $target) = $self->{types}->get_builtin($param->{type});
				if ($builtin eq 'bool') {
					$ret{return_code} = [
						"$ret{name} = (bool)(PyObject_IsTrue(py_$ret{name}));"
					];
				}
				elsif ($builtin eq 'char**') {
					my $count = $self->{count};
					$ret{return_code} = [
						"$ret{name} = PyList2CharArray(py_$ret{name}, (int)$count->{name});"
					];
				}
				elsif ($builtin eq 'object' or $builtin eq 'responder') {
					my @n = split /\./, $target;
					my $objtype = join('_', @n, 'Object');
					$ret{return_code} = [
						"$ret{name} = *((($objtype*)py_$ret{name})->cpp_object);"
					];
				}
				elsif ($builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
					my @n = split /\./, $target;
					my $objtype = join('_', @n, 'Object');
					$ret{return_code} = [
						"$ret{name} = ((($objtype*)py_$ret{name})->cpp_object);"
					];
				}
				else {
					die "Unsupported type: $param->{type}/$builtin/$target";
				}
			}
			else {
				die "Unsupported type: $param->{type} ($item)";
			}
		}
		
		if ($param->action eq $action) {
			$ret{format_name} = "&$ret{name}";
			
			# format code for pulling out of tuple
			my $type = $param->{type};
			$param->{deref} and $type=~s/\*$//;
			my $item = $self->{types}->get_format_item($type);
			$item or warn "No format item for $type";
			$ret{format_item} = $item;
			
			# some types are parsed as Python objects; deal with them here
			if ($item=~/^O/) {
				$ret{format_name} = "&py_$param->{name}";
				$ret{format_definition} = "PyObject* py_$param->{name}";
				
				my ($builtin, $target) = $self->{types}->get_builtin($param->{type});
				if ($builtin eq 'bool') {
					$ret{format_code} = [ "$param->{name} = (bool)(PyObject_IsTrue(py_$param->{name}));" ];
				}
				elsif ($builtin eq 'char**') {
					my $count = $self->{count};
					$ret{format_code} = [ "$param->{name} = PyList2CharArray(py_$param->{name}, (int)$count->{name});" ];
				}
				elsif ($builtin eq 'object' or $builtin eq 'responder') {
					my @n = split /\./, $target;
					my $objtype = join('_', @n, 'Object');
					$ret{format_code} = [ "$param->{name} = *((($objtype*)py_$param->{name})->cpp_object);" ];
					
				}
				elsif ($builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
					my @n = split /\./, $target;
					my $objtype = join('_', @n, 'Object');
					$ret{format_code} = [ "$param->{name} = (($objtype*)py_$param->{name})->cpp_object;" ];
					
				}
				else {
					die "Unsupported type: $param->{type}/$builtin/$target";
				}
			}
		}
		
		$self->{cpp_input} = \%ret;
	}
	
	return $self->{cpp_input}
}

sub as_input_to_cpp {
	my ($self) = @_;
	$self->as_cpp('input');
}

sub as_output_to_cpp {
	my ($self) = @_;
	$self->as_cpp('output');
}

sub as_input_to_python {
	my ($self) = @_;
	
	unless ($self->{python_input}) {
		my $param = $self->{param};
		
		if ($param->isa('Return') and
			($param->{type} eq 'void' or not $param->{type})
			) {
			$self->{python_input} = {
				type => 'void',
			};
			return $self->{python_input};
		}
		
		my %ret;
		
		# name and type
		$ret{name} = $param->{name};
		$ret{type} = $param->{type};
		
		# define the c++ var
		$ret{definition} = "$param->{type} $param->{name}";
		
		# name as it should be passed to Py_BuildValue
		$ret{format_name} = $param->name;
		
		# format code for building value
		my $type = $param->{type};
		$param->{deref} and $type=~s/\*$//;
		my $item = $self->{types}->get_format_item($type);
		$item or warn "No format item for $type";
		$ret{format_item} = $item;
		
		# some types are parsed as Python objects; deal with them here
		if ($item=~/^O/) {
			$ret{format_name} = "py_$param->{name}";
			$ret{format_definition} = "PyObject* py_$param->{name}";
			
			my ($builtin, $target) = $self->{types}->get_builtin($param->{type});
			if ($builtin eq 'bool') {
				delete $ret{format_definition};
				$ret{format_item} = 'b';
				$ret{format_name} = "($param->{name} ? 1 : 0)";
			}
			elsif ($builtin eq 'char**') {
				my $count = $self->{count};
				$ret{format_code} = [ "py_$param->{name} = CharArray2PyList($param->{name}, (int)$count->{name});" ];
			}
			elsif ($builtin eq 'object' or $builtin eq 'responder') {
				$ret{format_name} = "(PyObject*)py_$param->{name}";
				$ret{format_code} = [ "... (HANDLE OBJECT HERE)" ];
			}
			elsif ($builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
				my ($builtin, $target) = $self->{types}->get_builtin($param->{type});
				(my $type = $target)=~s/\./_/g; $type .= '_Object';
				$ret{format_definition} = "$type* py_$param->{name}";
				$ret{format_name} = "(PyObject*)py_$param->{name}";
				$ret{format_code} = [
					qq(py_$param->{name} = new $type();),
					qq(py_$param->{name}->cpp_object = $param->{name};),
				];
				
				if ($param->{must_not_delete}) {
					push @{ $ret{format_code} },
						qq(// cannot delete this object; we do not own it),
						qq(py_$param->{name}->can_delete_cpp_object = false;);
				}
				else {
					push @{ $ret{format_code} },
						qq(// we own this object, so we can delete it),
						qq(py_$param->{name}->can_delete_cpp_object = true;);
				}
			}
			else {
				die "Unsupported type: $param->{type}/$builtin/$target";
			}
		}
		
		$self->{python_input} = \%ret;
	}
	
	return $self->{python_input};
}

sub as_output_to_python {
	my ($self) = @_;
	$self->as_input_to_python;
}

sub as_error_to_python {
	my ($self) = @_;
	
	unless ($self->{python_error}) {
		my $param = $self->{param};
		my %ret;
		
		$ret{name} = $param->{name};
		$ret{success} = $param->{success};
		
		my $type = $param->{type};
		if ($param->{deref}) {
			$type=~s/\*$//;
		}
		$ret{format_item} = $self->{types}->get_format_item($type);
		
		$self->{python_error} = \%ret;
	}
	
	return $self->{python_error};
}

1;
