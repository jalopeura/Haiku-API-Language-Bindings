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
		cpp_call => "$cpp_class_name}::" . $self->name,
		perl_name => $perl_name,
		add_CLASS => 1,
		extra_items => [
			'// item 0: CLASS',	# added variable
		],
	);
}

sub Xgenerate_xs_function {
	my ($self, $options) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	$options->{cpp_call_name} = "$cpp_class_name}::" . $self->name; 
	
	# first perl input will be class
	$options->{input} ||= [];
	unshift @{ $options->{args} }, "CLASS";
	
	$options->{input_defs} ||= [];
	unshift @{ $options->{input} }, "char* CLASS;";
	
	$options->{precode} ||= [];
	# get defaults, with an offset of 1 for the CLASS variable
	my $code = $self->params->default_var_code(1);
	$code and unshift @{ $options->{precode} }, @$code;
	
	$self->generate_xs_body_code($options);
	
	$self->SUPER::generate_xs_function($options);
}

1;
