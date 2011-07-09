use Common::Constants;
use Python::BaseObject;

package Python::Constants;
use File::Spec;
use File::Path;
use strict;
our @ISA = qw(Constants Python::BaseObject);

sub generate {
	my ($self, $folder, $ext_prefix) = @_;
	
	my $class = $self->class;
	$class->{constant_defs} = [];
	$class->{constant_code} = [];
	
	if ($self->has('constants')) {
		for my $c ($self->constants) {
			$c->generate;
		}
	}
}

package Python::Constant;
use strict;
our @ISA = qw(Constant Python::BaseObject);

sub generate {
	my ($self) = @_;	
	
	my $class = $self->class;
	my $constant_name = $self->name;
	(my $class_name = $class->python_name)=~s/\./_/g;
	my $object_name = "${class_name}_$constant_name";
	
	(my $package_name = $self->class->package_name)=~s/\./_/g; $package_name .= '_module';
	
	push @{ $class->{constant_defs} }, "PyObject* $object_name;";
	push @{ $class->{constant_code} },
		qq($object_name = PyInt_FromLong((long)$constant_name);),
		qq(Py_INCREF($object_name);),
		qq(PyModule_AddObject($package_name, "$constant_name", $object_name);),
		"";
}

1;
