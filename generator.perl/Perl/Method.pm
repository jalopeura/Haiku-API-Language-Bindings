package Perl::Method;
use Perl::Functions;
use strict;
our @ISA = qw(Method Perl::Function);

sub generate_xs_function {
	my ($self, $options) = @_;
	my $name = $self->name;
	my $cpp_class_name = $self->cpp_class_name;
	$options->{name} = "${cpp_class_name}::$options->{name}";
	
	$options->{code} ||= [];
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	if ($options->{rettype} eq 'void') {
#push @{ $options->{code} }, qq(DEBUGME(4, "About to call cpp method ${cpp_class_name}::$name"););
		push @{ $options->{code} }, qq(THIS->$name($call_args););
#push @{ $options->{code} }, qq(DEBUGME(4,"Back from cpp call"););
	}
	else {
		my $type = $self->types->type($options->{rettype});
		if ($type->has('target')) {
			push @{ $options->{init} }, "$options->{rettype} OBJ;";
			my $class = $type->target;
			push @{ $options->{code} },
				qq(OBJ = THIS->$name($call_args););
			
			if ($options->{rettype}=~/\*$/) {
				push @{ $options->{code} },
					qq{RETVAL = create_perl_object((void*)OBJ, "$class");};
			}
			else {
				push @{ $options->{code} },
					qq{RETVAL = create_perl_object((void*)&OBJ, "$class");};
			}
			
			if ($self->params->cpp_output->must_not_delete) {
				push @{ $options->{code} },
					qq{must_not_delete_cpp_object(RETVAL, true);},
			}
			
			# we're creating the object ourself, so we change the rettype
			$options->{rettype} = 'SV*';
		}
		else {
			push @{ $options->{code}}, qq(RETVAL = THIS->$name($call_args););
		}
	}
		
	$self->SUPER::generate_xs_function($options);
}

1;
