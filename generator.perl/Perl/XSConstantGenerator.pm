package Perl::Generator;
use strict;

=pod

generate_xs_method

we should make it generate a single XS sub for all overloaded C++ subs

this will require a lot more work; for now let's use the simpler way

each overloaded function gets passed through once

=cut

sub generate_xs_constant {
	my ($self, $fh, %options) = @_;
	
	my $constant = $options{constant};
	my $cpp_class_name = $options{cpp_class_name};
	my $perl_class_name = $options{perl_class_name};
	my $perl_module_name = $options{perl_module_name};
	
	my $name = $constant->{name};
	
	print $fh <<CONST;
SV*
$name()
	CODE:
		RETVAL = newSViv($name);
	OUTPUT:
		RETVAL

CONST
}

1;
