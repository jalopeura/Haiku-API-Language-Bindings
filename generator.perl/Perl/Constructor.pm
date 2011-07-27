package Perl::Constructor;
use Perl::Functions;
use strict;
our @ISA = qw(Constructor Perl::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'new';
}

sub generate_xs {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	
	unless ($self->has('return')) {	
		$self->{return} ||= bless {
			name   => 'retval',
			type_name => $cpp_class_name . '*',
			target => $self->perl_class_name,
			action => 'output',
			types  => $self->types,
			needs_deref => 0,
			must_not_delete => $self->package->must_not_delete,
		}, 'Perl::Return';
		$self->{params} ||= new Perl::Params;
		$self->params->add($self->{return});
	}
	
	my %options = (
		cpp_call => "new $cpp_class_name",
		perl_name => "${cpp_class_name}::new",
		extra_items => [
			'// item 0: CLASS',	# variable (which may be automatic or added)
		],
	);
	
	if ($self->has('overload_name')) {
		$options{perl_name} = 'new' . $self->overload_name;
		$options{add_CLASS} = 1;
		$options{comment} = <<COMMENT;
# Note that this method is not prefixed by the class name.
#
# This is because for prefixed methods, xsubpp will turn the first perl
# argument into the CLASS variable (a char*) if the method name is 'new',
# and into the THIS variable (the object pointer) otherwise. So we need to
# trick xsubbpp by leaving off the prefix and defining CLASS ourselves
COMMENT
	}
	
	if ($self->package->is_responder) {
		$options{custom_constructor} = 1;
	}
	
	$self->SUPER::generate_xs(%options);
}

sub Xgenerate_xs_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	$options->{rettype} = 'SV*';
	$options->{retcount} = 1;
	
	if ($self->has('overload_name')) {
		$options->{input} ||= [];
		unshift @{ $options->{args} }, "CLASS";
		
		$options->{input_defs} ||= [];
		unshift @{ $options->{input} }, "char* CLASS;";
		
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
	
	$options->{precode} ||= [];
	# get defaults, with an offset of 1 for the CLASS variable
	my $code = $self->params->default_var_code(1);
	$code and unshift @{ $options->{precode} }, @$code;
	
	$options->{init} ||= [];
	push @{ $options->{init} }, "$cpp_class_name* THIS;";
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	
	$options->{code} ||= [];
	
	my $mnd = $self->package->must_not_delete ? 'true' : 'false';
	
	push @{ $options->{code} }, 
		qq{THIS = new $cpp_class_name($call_args);},
		qq{RETVAL = newSV(0);},
		qq{sv_setsv(RETVAL, create_perl_object((void*)THIS, CLASS, $mnd));};
	
	if ($self->package->is_responder) {
		push @{ $options->{code} },
			qq(if (THIS != NULL) {),
			qq(\tTHIS->perl_link_data = get_link_data(RETVAL);),
			qq(});
	}
	
	$self->SUPER::generate_xs_function($options);
}

sub generate_h {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	my $inputs = join(', ', @{ $self->params->as_cpp_funcdef });
	print { $self->package->hh } qq(\t\t$cpp_class_name($inputs);\n);
}

sub generate_cpp {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	my $cpp_parent_name = $self->package->cpp_parent;

	my $inputs = join(', ', @{ $self->params->as_cpp_funcdef });
	my $parent_inputs = join(', ', @{ $self->params->as_cpp_parent_call });
	
	print { $self->package->cpph } <<CONSTRUCTOR;
${cpp_class_name}::$cpp_class_name($inputs)
	: $cpp_parent_name($parent_inputs) {}

CONSTRUCTOR
}

1;
