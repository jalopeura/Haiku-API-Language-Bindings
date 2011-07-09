package Python::Destructor;
use Python::Functions;
use strict;
our @ISA = qw(Destructor Python::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'DESTROY';
}

sub generate_cc_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	$options->{rettype} = 'void';
	$options->{input} = "${python_object_prefix}_Object* python_self";
	
	$options->{init} = [
		"$cpp_class_name* cpp_obj;",
		"object_link_data* link;",
	];
	
	$options->{code} = [
		qq(if (python_self->cpp_object != NULL) {),
		qq(	if (python_self->can_delete_cpp_object) {),
		qq(		delete python_self->cpp_object;),
		qq(	}),
	];	
	if ($self->class->is_responder) {
		push @{ $options->{code} },
		qq(	else {),
		qq(		python_self->cpp_object->python_object = NULL;),
		qq(	});
	}
	
	push @{ $options->{code} },	qq(});
	
	$self->SUPER::generate_cc_function($options);
}

sub generate_h {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	print { $self->class->hh } <<DESTRUCTOR;
		virtual ~$cpp_class_name();
DESTRUCTOR
}

sub generate_cpp {
	my ($self) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	
	print { $self->class->cpph } <<DESTRUCTOR;
${cpp_class_name}::~$cpp_class_name() {
//	DEBUGME(4, "Deleting $cpp_class_name");
	
	// if we still have a python object,
	// remove ourselves from it
	if (python_object != NULL) {
		python_object->cpp_object = NULL;
		python_object->can_delete_cpp_object = false;
	}
}

DESTRUCTOR
}

1;
