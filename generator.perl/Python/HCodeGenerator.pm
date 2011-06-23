package Python::ResponderPyType;
use strict;

sub generate_h_preamble {
	my ($self) = @_;
	
	print { $self->{hh} } <<TOP;
/*
 * Automatically generated file
 */

class $self->{cpp_class} : public $self->{cpp_parent} {
	public:
TOP
}

sub generate_h_method {
	my ($self, $method, $params) = @_;
	
	my $fh = $self->{hh};
	
	my $cpp_class_name = $self->{cpp_class};
	my $perl_class_name = $self->{name};
	
	my @inputs;
	
	for my $p (@{ $params->cpp_inputs }) {
		my $param = $p->as_input_to_cpp;
		push @inputs, $param->{funcdef_definition};
	}
	
	my $inputs = join(', ', @inputs);
	my $name = $method->name;
	
	if ($method->isa('Constructor')) {
		print $fh qq(\t\t$cpp_class_name($inputs);\n);
	}
	elsif ($method->isa('Destructor')) {
		print $fh qq(\t\tvirtual ~$cpp_class_name();\n);
	}
	elsif ($method->isa('Event')) {
		my $retval = $params->{cpp_output}->as_output_to_cpp;
		print $fh qq(\t\t$retval->{type} $name($inputs);\n);
	}
}

sub generate_h_postamble {
	my ($self) = @_;
	
	(my $type = $self->{name})=~s/\./_/g; $type .= '_Object*';

	print { $self->{hh} } <<END;
		$type python_object;
}; // $self->{cpp_class}
END
}

1;
