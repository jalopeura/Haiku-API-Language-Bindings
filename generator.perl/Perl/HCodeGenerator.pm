package Perl::ResponderPackage;
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
	for my $p (@{ $params->{cpp_inputs} }) {
		push @inputs, "$p->{type} $p->{name}";
	}
	my $inputs = join(', ', @inputs);
	my $rettype = $params->{cpp_output}{type};
	my $name = $method->name;
	
	if ($method->isa('Constructor')) {
		print $fh qq(\t\t$cpp_class_name($inputs);\n);
	}
	elsif ($method->isa('Destructor')) {
		print $fh qq(\t\tvirtual ~$cpp_class_name();\n);
	}
	elsif ($method->isa('Event')) {
		print $fh qq(\t\t$rettype $name($inputs);\n);
	}
	
}

sub generate_h_postamble {
	my ($self) = @_;

	print { $self->{hh} } <<END;
		object_link_data* perl_link_data;
}; // $self->{cpp_class}
END
}

1;
