package Python::ResponderPyType;
use strict;

sub generate_cpp_preamble {
	my ($self) = @_;
	
	print { $self->{cpph} } <<TOP;
/*
 * Automatically generated file
 */
 
#include "$self->{filename}.h"

TOP
}

sub generate_cpp_method {
	my ($self, $method, $params) = @_;
	
	my $fh = $self->{cpph};
	
	my $cpp_class_name = $self->{cpp_class};
	my $cpp_parent_name = $self->{cpp_parent};
	my $perl_class_name = $self->{name};
	
	my (@inputs_from_cpp, @inputs_to_parent);
	
	for my $p (@{ $params->cpp_inputs }) {
		my $param = $p->as_input_to_python;
		push @inputs_from_cpp, $param->{definition};
		push @inputs_to_parent, $param->{name};
	}
	
#	my (@inputs, @parent_inputs);
#	for my $p (@{ $params->{cpp_inputs} }) {
#		push @inputs, "$p->{type} $p->{name}";
#		push @parent_inputs, $p->{name};
#	}
	my $cpp_inputs = join(', ', @inputs_from_cpp);
	my $parent_inputs = join(', ', @inputs_to_parent);
#	my $rettype = $params->{cpp_output}{type};
	my $name = $method->name;
	
	if ($method->isa('Constructor')) {
		print $fh <<FUNC;
${cpp_class_name}::$cpp_class_name($cpp_inputs)
	: $cpp_parent_name($parent_inputs) {}

FUNC
	}
	elsif ($method->isa('Destructor')) {
		(my $type = $self->{name})=~s/\./_/g; $type .= '_Object*';
		print $fh <<FUNC;
${cpp_class_name}::~$cpp_class_name() {
	DEBUGME(4, "Deleting $cpp_class_name");
	
	// if we still have a python object,
	// remove ourselves from it
	if (python_object != NULL) {
		python_object->cpp_object = NULL;
		python_object->can_delete_cpp_object = false;
	}
}

FUNC

	}
	elsif ($method->isa('Event')) {
#		my ($python_input_format, @python_input_defs, @python_inputs, @python_pre_code);
		my (@var_defs, @inputs_to_python, $python_input_format,
			@pre_input_build, @post_return_parse, $void_return);
		for my $p (@{ $params->python_inputs }) {
			my $param = $p->as_input_to_python;
			push @inputs_to_python, $param->{format_name};
			$python_input_format .= $param->{format_item};
			if ($param->{format_definition}) {
				push @var_defs, $param->{format_definition};
			}
			if ($param->{format_code}) {
				push @pre_input_build, @{ $param->{format_code} };
			}
		}
		my $output_to_cpp = $params->cpp_output->as_output_to_cpp;
		if ($output_to_cpp->{type} eq 'void') {
			$void_return = 1;
		}
		else {
			push @var_defs, $output_to_cpp->{definition};
			push @var_defs, "PyObject* $output_to_cpp->{return_name}";
			if ($output_to_cpp->{format_definition}) {
				push @var_defs, $output_to_cpp->{format_definition};
			}
			if ($output_to_cpp->{format_code}) {
				push @post_return_parse, @{ $output_to_cpp->{format_code} };
			}
			if ($output_to_cpp->{return_code}) {
				push @post_return_parse, @{ $output_to_cpp->{return_code} };
			}
		}
		
		my $python_inputs;
		if ($python_input_format) {
			$python_inputs = join(', ', qq("$python_input_format"), @inputs_to_python);
		}
		else {
			$python_inputs = 'NULL';
		}
		
		print $fh <<FUNC;
$output_to_cpp->{type} ${cpp_class_name}::$name($cpp_inputs) {
	if (python_object == NULL) {
		return ${cpp_parent_name}::$name($parent_inputs);
	}
	else {
FUNC
		if (@var_defs) {
			print $fh qq(\t\t// defs\n);
			print $fh "\t\t", join(";\n\t\t", @var_defs),";\n\n";
		}
		if (@pre_input_build) {
			print $fh "\t\t", join("\n\t\t", @pre_input_build),"\n\n";
		}
		
		if ($void_return) {
			print $fh <<FUNC
		// call the proper method
		PyObject_CallMethod((PyObject*)python_object, "$name", $python_inputs);
FUNC
		}
		else {			
			print $fh <<FUNC;
		// call the proper method
		$output_to_cpp->{return_name} = PyObject_CallMethod((PyObject*)python_object, "$name", $python_inputs);
		
FUNC
		}
		
		if (@post_return_parse) {
			print $fh qq(\t\t// parse the return value\n);
			print $fh "\t\t", join("\n\t\t", @post_return_parse),"\n\n";
		}
		
		unless ($void_return) {
			print $fh "\t\treturn $output_to_cpp->{name};\n";
		}
		
		print $fh <<FUNC;
	}
} // ${cpp_class_name}::$name

FUNC
	}
}

sub generate_cpp_postamble {
	# nothing to do
}

1;
