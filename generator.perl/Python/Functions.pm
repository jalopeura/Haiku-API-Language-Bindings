use Common::Functions;
use Python::BaseObject;
use Python::Constructor;
use Python::Destructor;
use Python::Method;
use Python::Event;
use Python::Static;
use Python::Plain;
use Python::Params;

package Python::Functions;
use strict;
our @ISA = qw(Functions Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('constructors')) {
		for my $c ($self->constructors) {
			$c->generate;
		}
	}
	
	if ($self->has('destructor')) {
		$self->destructor->generate;
	}
	
	if ($self->has('methods')) {
		for my $m ($self->methods) {
			$m->generate;
		}
	}
	
	if ($self->has('events')) {
		for my $e ($self->events) {
			$e->generate;
		}
	}
	
	if ($self->has('statics')) {
		for my $s ($self->statics) {
			$s->generate;
		}
	}
	
	if ($self->has('plains')) {
		for my $p ($self->plains) {
			$p->generate;
		}
	}
}

# convenience package for inheritance
package Python::Function;
use strict;
our @ISA = qw(Python::BaseObject);

sub finalize_upgrade {
	my ($self) = @_;
	
	if ($self->has('params')) {
		$self->{params} = new Python::Params($self->params);
	}
	else {
		$self->{params} = new Python::Params;
	}
	
	if ($self->has('return')) {
		$self->{params} ||= new Python::Params();
		$self->params->add($self->return);
	}
}

sub generate {
	my ($self) = @_;
	
	$self->generate_cc;
	
	if ($self->class->is_responder) {
		$self->generate_h;
		$self->generate_cpp;
	}
	else {
		$self->generate_py;	# responders don't generate PY functions
	}
}

sub generate_py {}	# nothing to do

# desecndant class should place the function in the correct table
# and then call this parent class function to generate the table itself
sub generate_cc {
	my ($self, %options) = @_;
	
	$options{name} ||= $self->name;
	$options{cpp_name} ||= 'CPP_NAME';
	$options{python_input} ||= [qw(PY_OBJ_OR_CLS PY_ARGS PY_KWDS)];
	$options{rettype} ||= 'PyObject*';
	
	my @defs;
	my $parse_format;
	my @parse_args;
	my @cpp_args;
	my $build_format;
	my @build_args;
	my @precode;
	my @parsecode;
	my @postcode;
	my $retval;
	my $retname;
	my @outputs;
	
	if ($self->params->has('cpp_input')) {
		my $seen_default;
		for my $param ($self->params->cpp_input) {
			push @cpp_args, $param->as_cpp_arg;
			my $action = $param->action;
			if ($action eq 'input') {
				push @defs, $param->as_cpp_def;
				my $item = $param->type->format_item;
				for (qw(array_length string_length max_array_length max_string_length)) {
					if ($param->has($_)) {
						$item = 'O';
					}
				}
				
				if ($param->has('default') and not $seen_default) {
					$parse_format .= '|';
					$seen_default = 1;
				}
				$parse_format .= $item;
				
				if ($item=~/^O/) {
					my $pyobj_name = 'py_' . $param->name;
					my $options = {
						input_name => $pyobj_name,
						output_name => $param->name,
						must_not_delete => $param->must_not_delete,
						repeat => $param->repeat,
					};
					for (qw(array_length string_length max_array_length max_string_length)) {
						if ($param->has($_)) {
							$options->{$_} = $param->{$_};
						}
					}
					if ($param->has('count')) {
						$options->{set_array_length} = 1;
					}
					if ($param->has('length')) {
						$options->{set_string_length} = 1;
					}
					my ($arg_defs, $arg_code) = $param->arg_parser($options);
		
					if ($param->type->has('target') and my $target = $param->type->target and
						not $param->has('array_length')) {
						(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
						push @defs, "$objtype* $pyobj_name; // from generate_py()";
					}
					else {
						push @defs, "PyObject* $pyobj_name; // from generate_py ()",	# may need to fix this for C++ objects
					}
					
					push @defs, @$arg_defs;
					push @parsecode, @$arg_code;
					push @parse_args, '&' . $pyobj_name;
				}
				else {
					push @parse_args, '&' . $param->name;
				}
			}
			elsif ($action eq 'output') {
				push @defs, $param->as_cpp_def;
				push @outputs, $param;
			}
			elsif ($action=~/(length|count)\[/) {
				push @defs, $param->as_cpp_def;
			}
			elsif ($action eq 'error') {
				my ($def, $code) = $param->python_error_code($options{rettype} eq 'int');
				push @defs, $def;
				push @postcode, @$code;
			}
		}
	}
	
	if ($self->params->has('cpp_output') and $self->params->cpp_output->type_name ne 'void') {
		$retval = $self->params->cpp_output;
		my $action = $retval->action;
		if ($action eq 'output') {
			push @defs, $retval->as_cpp_def;
			unshift @outputs, $retval;
		}
		elsif ($action eq 'error') {
			my ($def, $code) = $retval->python_error_code($options{rettype} eq 'int');
			push @defs, $def;
			push @postcode, @$code;
		}
	}
	
	if (@parse_args) {
		my $python_args = $options{python_args};
		my $parse_args = join(', ', @parse_args);
		unshift @parsecode,
			qq(PyArg_ParseTuple($python_args, "$parse_format", $parse_args););
	}
	
	if (@outputs) {
		if ($#outputs) {	# multiple return
			for my $i (0..$#outputs) {
				my $param = $outputs[$i];
				my $item = $param->type->format_item;
				my $pyobj_name = 'py_' . $param->name;
				if ($item=~/^O/) {
					my $options = {
						input_name => $param->name,
						output_name => $pyobj_name,
						must_not_delete => $param->must_not_delete,
					};
					for (qw(count length repeat)) {
						if ($param->has($_)) {
							$options->{$_} = $param->{$_};
						}
					}
					for (qw(array_length string_length max_array_length max_string_length)) {
						if ($param->has($_)) {
							$options->{$_} = $param->{$_};
						}
					}
					my ($defs, $code) = $param->arg_builder($options);
					
					if ($param->type->has('target') and my $target = $param->type->target and
						not $param->has('array_length')) {
						(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
						push @defs, "$objtype* $pyobj_name; // from generate_py()";
					}
					else {
						push @defs, "PyObject* $pyobj_name; // from generate_py()",	# may need to fix this for C++ objects
					}
					
					push @defs, @$defs;
					push @postcode, @$code;
					push @build_args, $pyobj_name;
				}
				else {
					push @build_args, $param->name;
				}
				$build_format .= $item;
			}
			
			if (@postcode) {
				push @postcode, '';
			}
			if ($options{rettype} eq 'int') {	# __init__ (constructor)
				push @postcode, "return 0;";
			}
			else {
				my $build_args = join(', ', @build_args);
				push @postcode, qq(return Py_BuildValue("$build_format", $build_args););
			}
		}
		else {	# single return
			my $pyobj_name = 'py_' . $outputs[0]->name;
			
			my $obj_return;
			unless ($self->isa('Python::Constructor')) {
				if ($outputs[0]->type->has('target') and my $target = $outputs[0]->type->target and
					not $outputs[0]->has('array_length')) {
					(my $objtype = $target)=~s/\./_/g; $objtype .= '_Object';
					push @defs, "$objtype* $pyobj_name; // from generate_py() (for outputs)";
					$obj_return = 1;
				}
				else {
					push @defs, "PyObject* $pyobj_name; // from generate_py()",	# may need to fix this for C++ objects
				}
			}
			
			my $options = {
				input_name => $outputs[0]->name,
				output_name => $pyobj_name,
				must_not_delete => $outputs[0]->must_not_delete,
			};
			for (qw(count length repeat)) {
				if ($outputs[0]->has($_)) {
					$options->{$_} = $outputs[0]->{$_};
				}
			}
			for (qw(array_length string_length max_array_length max_string_length)) {
				if ($outputs[0]->has($_)) {
					$options->{$_} = $outputs[0]->{$_};
				}
			}
			my ($defs, $code) = $outputs[0]->arg_builder($options);
			push @defs, @$defs;
			push @postcode, @$code;
			
			if ($self->isa('Python::Constructor')) {
				if ($self->has('overload_name')) {
					push @postcode, "return (PyObject*)python_self;";
				}
				else {
					push @postcode, "return 0;";
				}
			}
			elsif ($obj_return) {
				push @postcode, "return (PyObject*)$pyobj_name;";
			}
			else {
				push @postcode, "return $pyobj_name;";
			}
		}
	}
	else {
		push @postcode, "Py_RETURN_NONE;";
	}
	
	my $fh = $self->class->cch;
	
	if ($options{comment}) {
		print $fh $options{comment};
	}
	
	my $python_input = join(', ', @{ $options{python_input} });
	
	print $fh <<DEF;
//static $options{rettype} $options{name}($python_input);
static $options{rettype} $options{name}($python_input) {
DEF

	if ($options{predefs}) {
		print $fh map { "\t$_\n" } @{ $options{predefs} };
	}
	
	if (@defs) {
		print $fh map { "\t$_\n" } @defs;
		print $fh "\t\n";
	}
	
	if ($options{precode}) {
		print $fh map { "\t$_\n" } @{ $options{precode} };
		print $fh "\t\n";
	}
	
	if (@precode) {
		print $fh map { "\t$_\n" } @precode;
		print $fh "\t\n";
	}
	
	if (@parsecode) {
		print $fh map { "\t$_\n" } @parsecode;
		print $fh "\t\n";
	}
	
	my $cpp_input = join(', ', @cpp_args);
	if ($retval) {
		print $fh "\t$retval->{name} = $options{cpp_name}($cpp_input);\n";
		if ($retval->type->has('target') and $retval->type_name=~/\*$/) {
			print $fh "\tif ($retval->{name} == NULL)\n";
			if ($options{rettype} eq 'int') {	# __init__ (constructor)
				print $fh "\t\treturn -1;";
			}
			else {
				print $fh "\t\tPy_RETURN_NONE;";
			}
			print $fh "\t\n";
		}
	}
	else {
		print $fh "\t$options{cpp_name}($cpp_input);\n";
	}
	
	if ($options{postcode}) {
		print $fh map { "\t$_\n" } @{ $options{postcode} };
		print $fh "\t\n";
	}
	
	if (@postcode) {
		print $fh "\t\n";
		print $fh map { "\t$_\n" } @postcode;
	}
	
	print $fh "}\n\n";
}

1;
