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

sub Xgenerate_xs_function {
	my ($self, $options) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	$options->{cpp_call_name} = $self->name;
	
	$options->{precode} ||= [];
	# get defaults, with an offset of 0 since there are no added variables
	my $code = $self->params->default_var_code(1);
	$code and unshift @{ $options->{precode} }, @$code;
	
	$self->generate_xs_body_code($options);
		
	$self->SUPER::generate_xs_function($options);
}

1;
