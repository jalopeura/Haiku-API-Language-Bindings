package Perl::Method;
use Perl::Functions;
use strict;
our @ISA = qw(Method Perl::Function);

sub generate_xs {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	
	my $perl_name = $self->has('overload_name') ?
		$self->overload_name : $self->name;
	
	$self->SUPER::generate_xs(
		cpp_call => 'THIS->' . $self->name,
		perl_name => "${cpp_class_name}::$perl_name",
		extra_items => [
			'// item 0: THIS',	# automatic variable
		],
	);
}

1;
