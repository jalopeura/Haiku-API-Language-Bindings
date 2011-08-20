package Perl::Destructor;
use Perl::Functions;
use strict;
our @ISA = qw(Destructor Perl::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'DESTROY';
}

sub generate_xs {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	my $fh = $self->package->xsh;
	
	print $fh <<DESTRUCTOR;
# Note that this method is not prefixed by the class name.
#
# This is because if we prefix the class name the first argument is
# automatically converted into the THIS pointer, and we no longer have
# access to the Perl object. But we need that access in order to determine
# whether we're allowed to delete the C++ object, and to clean up the Perl
# object.
void
DESTROY(perl_obj)
	INPUT:
		SV* perl_obj;
	INIT:
		$cpp_class_name* cpp_obj;
		object_link_data* link;
	CODE:
		DEBUGME(2,"Deleting perl wrapper for $cpp_class_name");
		DUMPME(1,perl_obj);
		link = get_link_data(perl_obj);
		if (link != NULL && ! PL_dirty && link->can_delete_cpp_object) {
			DEBUGME(2,"-->Deleting the wrapped c++ object");
			cpp_obj = ($cpp_class_name*)link->cpp_object;
			delete cpp_obj;
			link->cpp_object = NULL;
		}
		unlink_perl_object(perl_obj);

DESTRUCTOR
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
	DEBUGME(2,"Deleting $cpp_class_name");
	// if the perl object was previously unlinked,
	// we no longer need to keep the data around
	if (perl_link_data->perl_object == NULL)
		delete perl_link_data;
}

DESTRUCTOR
}

1;
