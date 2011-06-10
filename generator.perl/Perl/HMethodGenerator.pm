package Perl::Generator;
use strict;

sub generate_h_method {
	my ($self, $fh, %options) = @_;
	
	my $function = $options{function};
	my $params = $options{params};
	my $cpp_class_name = $options{cpp_class_name};
	my $cpp_parent_name = $options{cpp_parent_name};
	
	my @inputs;
	for my $p (@{ $params->{cpp_inputs} }) {
		push @inputs, "$p->{type} $p->{name}";
	}
	my $inputs = join(', ', @inputs);
	my $rettype = $params->{cpp_output}{type};
	my $name = $function->name;
	
	if ($function->isa('Constructor')) {
		print $fh qq(\t\t$cpp_class_name($inputs);\n);
	}
	elsif ($function->isa('Destructor')) {
		print $fh qq(\t\tvirtual ~$cpp_class_name();\n);
	}
	elsif ($function->isa('Event')) {
		print $fh qq(\t\t$rettype $name($inputs);\n);
	}
	
}

1;
