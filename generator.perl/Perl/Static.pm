package Perl::Static;
use Perl::Functions;
use strict;
our @ISA = qw(Static Perl::Function);

sub generate_xs_function {
	my ($self, $options) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	my $name = "$cpp_class_name}::" . $self->name;
	
	# first perl input will be class
	$options->{input} ||= [];
	unshift @{ $options->{input} }, "CLASS";
	
	$options->{input_defs} ||= [];
	unshift @{ $options->{input_defs} }, "char* CLASS;";
	
	$options->{code} ||= [];
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	if ($options->{rettype} eq 'void') {
		push @{ $options->{code} }, qq($name($call_args););
	}
	else {
		my $type = $self->types->type($options->{rettype});
		if ($type->has('target')) {
			push @{ $options->{init} }, "$options->{rettype} OBJ;";
			$options->{rettype} = 'SV*';
			my $class = $type->target;
			push @{ $options->{code} },
				qq(OBJ = $name($call_args);),
				qq{RETVAL = create_perl_object((void*)OBJ, "$class");};
			
			if ($self->params->cpp_output->must_not_delete) {
				push @{ $options->{code} },
					qq{must_not_delete_cpp_object(RETVAL, true);},
			}
		}
		else {
			push @{ $options->{code} }, qq(RETVAL = $name($call_args););
		}
	}
	
	# call must be prefixed with class name
	my $name = $self->name;
	my $cpp_class_name = $self->cpp_class_name;
	$options->{name} = "${cpp_class_name}::$options->{name}";
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	if ($options->{rettype} eq 'void') {
		push @{ $options->{code} }, qq(THIS->$name($call_args););
	}
	else {
		my $type = $self->types->type($options->{rettype});
		if ($type->has('target')) {
			push @{ $options->{init} }, "$options->{rettype} OBJ;";
			$options->{rettype} = 'SV*';
			my $class = $type->target;
			push @{ $options->{code} },
				qq(OBJ = THIS->$name($call_args);),
				qq{RETVAL = create_perl_object((void*)OBJ, "$class");};
			
			if ($self->params->cpp_output->must_not_delete) {
				push @{ $options->{code} },
					qq{must_not_delete_cpp_object(RETVAL, true);},
			}
		}
		else {
			push @{ $options->{code} }, qq(RETVAL = THIS->$name($call_args););
		}
	}
		
	$self->SUPER::generate_xs_function($options);
}

1;
