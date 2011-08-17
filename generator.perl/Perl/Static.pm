package Perl::Static;
use Perl::Functions;
use strict;
our @ISA = qw(Static Perl::Function);

sub generate_xs {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	
	my $perl_name = $self->has('overload_name') ?
		$self->overload_name : $self->name;
	
	$self->SUPER::generate_xs(
		cpp_call => "$cpp_class_name\::" . $self->name,
		perl_name => $perl_name,
		add_CLASS => 1,
		extra_items => [
			'// item 0: CLASS',	# added variable
		],
	);
}

1;
