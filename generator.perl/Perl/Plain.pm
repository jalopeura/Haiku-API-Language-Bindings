package Perl::Plain;
use Perl::Functions;
use strict;
our @ISA = qw(Plain Perl::Function);

# don't need an overloaded version because we have no options to set

sub generate_xs {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	
	my $perl_name = $self->has('overload_name') ?
		$self->overload_name : $self->name;
	
	$self->SUPER::generate_xs(
		cpp_call => $self->name,
		perl_name => $perl_name,
	);
}

1;
