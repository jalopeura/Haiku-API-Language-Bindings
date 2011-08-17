package Python::Destructor;
use Python::Functions;
use strict;
our @ISA = qw(Destructor Python::Function);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->SUPER::finalize_upgrade;
	
	$self->{name} = 'DESTROY';
}

sub generate_cc {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my $fh = $self->class->cch;
	
	print $fh <<DESTRUCTOR;
//static void ${python_object_prefix}_DESTROY(${python_object_prefix}_Object* python_self);
static void ${python_object_prefix}_DESTROY(${python_object_prefix}_Object* python_self) {
	if (python_self->cpp_object != NULL) {
		if (python_self->can_delete_cpp_object) {
			delete python_self->cpp_object;
		}
DESTRUCTOR

	if ($self->class->is_responder) {
		print $fh <<DESTRUCTOR
		else {
			python_self->cpp_object->python_object = NULL;
		}
DESTRUCTOR
	}
	
	print $fh <<END;
	}
}

END
		
	$self->class->{destructor_name} = "${python_object_prefix}_DESTROY";
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
