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
			pass_as_pointer => 0,
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
