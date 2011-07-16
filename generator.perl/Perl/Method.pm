package Perl::Method;
use Perl::Functions;
use strict;
our @ISA = qw(Method Perl::Function);

sub generate_xs {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	
	$self->SUPER::generate_xs(
		cpp_call => 'THIS->' . $self->name,
		perl_name => "${cpp_class_name}::" . $self->name,
		extra_items => [
			'// item 0: THIS',	# automatic variable
		],
	);
}

sub generate_xs_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	$options->{cpp_call_name} = 'THIS->' . $self->name;
	$options->{name} = "${cpp_class_name}::$options->{name}";
	
	$options->{precode} ||= [];
	# get defaults, with an offset of 1 for the THIS variable
	my $code = $self->params->default_var_code(1);
	$code and unshift @{ $options->{precode} }, @$code;
	
	$self->generate_xs_body_code($options);
		
	$self->SUPER::generate_xs_function($options);
}

1;
