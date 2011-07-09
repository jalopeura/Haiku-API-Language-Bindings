package Perl::Constructor;
use Perl::Functions;
use strict;
our @ISA = qw(Constructor Perl::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'new';
}

sub generate_xs_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	$options->{rettype} = 'SV*';
	
	if ($self->has('overload_name')) {
		$options->{input} ||= [];
		unshift @{ $options->{input} }, "CLASS";
		
		$options->{input_defs} ||= [];
		unshift @{ $options->{input_defs} }, "char* CLASS;";
		
		$options->{comment} = <<COMMENT;
# Note that this method is not prefixed by the class name.
#
# This is because for prefixed methods, xsubpp will turn the first perl
# argument into the CLASS variable (a char*) if the method name is 'new',
# and into the THIS variable (the object pointer) otherwise. So we need to
# trick xsubbpp by leaving off the prefix and defining CLASS ourselves
COMMENT
	}
	else {
		$options->{name} = "${cpp_class_name}::$options->{name}";
	}
	
	$options->{init} ||= [];
	push @{ $options->{init} }, "$cpp_class_name* THIS;";
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	
	$options->{code} ||= [];
	
	push @{ $options->{code} }, 
		qq{THIS = new $cpp_class_name($call_args);},
		qq{RETVAL = newSV(0);},
		qq{sv_setsv(RETVAL, create_perl_object((void*)THIS, CLASS));};
	
	if ($self->package->is_responder) {
		push @{ $options->{code} },
			qq{THIS->perl_link_data = get_link_data(RETVAL);};
	}
	
	if ($self->package->must_not_delete) {
		push @{ $options->{code} },
			qq{must_not_delete_cpp_object(RETVAL, true);},
	}
	
	$self->SUPER::generate_xs_function($options);
}

sub generate_h {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	print { $self->package->hh } qq(\t\t$cpp_class_name($inputs);\n);
}

sub generate_cpp {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	my $cpp_parent_name = $self->package->cpp_parent;

	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	my $parent_inputs = join(', ', @{ $self->params->as_cpp_parent_input });
	
	print { $self->package->cpph } <<CONSTRUCTOR;
${cpp_class_name}::$cpp_class_name($inputs)
	: $cpp_parent_name($parent_inputs) {}

CONSTRUCTOR
}

1;
