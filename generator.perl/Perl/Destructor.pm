package Perl::Destructor;
use Perl::Functions;
use strict;
our @ISA = qw(Destructor Perl::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'DESTROY';
}

sub generate_xs_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	$options->{comment} = <<COMMENT;
# Note that this method is not prefixed by the class name.
#
# This is because if we prefix the class name the first argument is
# automatically converted into the THIS pointer, and we no longer have
# access to the Perl object. But we need that access in order to determine
# whether we're allowed to delete the C++ object, and to clean up the Perl
# object.
COMMENT
	
	$options->{input} = ['perl_obj'];
	$options->{input_defs} = ['SV* perl_obj;'];
	
	$options->{init} = [
		"$cpp_class_name* cpp_obj;",
		"object_link_data* link;",
	];
	
	$options->{code} = [
#qq(DEBUGME(4, "About to delete $cpp_class_name for %d", (IV)perl_obj);),
		qq(link = get_link_data(perl_obj);),
		qq(if (! PL_dirty && link->can_delete_cpp_object) {),
		qq(\tcpp_obj = ($cpp_class_name*)link->cpp_object;),
		qq(\tdelete cpp_obj;),
		qq(\tlink->cpp_object = NULL;),
		qq(}),
		qq(unlink_perl_object(perl_obj);),
	];
	
	$self->SUPER::generate_xs_function($options);
}

sub generate_h {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	print { $self->package->hh } <<DESTRUCTOR;
		virtual ~$cpp_class_name();
DESTRUCTOR
}

sub generate_cpp {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	print { $self->package->cpph } <<DESTRUCTOR;
${cpp_class_name}::~$cpp_class_name() {
	//DEBUGME(4, "Deleting $cpp_class_name for %d", perl_link_data->perl_object);
	
	// if the perl object was previously unlinked,
	// we no longer need to keep the data around
	if (perl_link_data->perl_object == NULL)
		delete perl_link_data;
}

DESTRUCTOR
}

1;