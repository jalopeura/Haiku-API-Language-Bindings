use Common::Properties;
use Python::BaseObject;

package Python::Properties;
use strict;
our @ISA = qw(Properties Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('properties')) {
		for my $p ($self->properties) {
			$p->generate;
		}
	}
}

package Python::Property;
use strict;
our @ISA = qw(Property Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	(my $class_name = $self->class->python_name)=~s/\./_/g;
	my $property_name = $self->name;
	my $property_type = $self->type;
	my $type = $self->types->type($property_type);
	my $item = $type->format_item;
	
	my $getter_name = "${class_name}_get$property_name";
	my $setter_name = "${class_name}_set$property_name";
	
	$class_name .= '_Object';
	
	my $get_var = my $set_var = "python_self->cpp_object->$property_name";
	
	my $pre_get = my $pre_set = "// no conversion necessary";
		
	# some types are parsed as Python objects; deal with them here
	if ($item=~/^O/) {			
		my ($builtin, $target) = $self->{types}->get_builtin($property_type);
		if ($builtin eq 'bool') {
			$item = 'b';
			$get_var = "(self->cpp_object->$property_name ? 1 : 0)";
			$set_var = "(bool)(PyObject_IsTrue(value))";
		}
		elsif ($builtin eq 'object_ptr' or $builtin eq 'responder_ptr') {
			(my $type = $target)=~s/\./_/g; $type .= '_Object';
			$get_var = "py_$property_name";
			$pre_get = "$type* py_$property_name;
	py_$property_name = new $type();
	py_$property_name->cpp_object = self->cpp_object->$property_name;";
			$set_var = "(($type*)value)->cpp_object";
		}
		else {
			die "Unsupported type: $property_type/$builtin/$target";
		}
	}
	
	if ($item=~/[ibhlBH]/) {
		$set_var = "($property_type)PyInt_AsLong(value)";
	}
	elsif ($item=~/[Ik]/) {
		$set_var = "($property_type)PyLong_AsLong(value)";
	}
	elsif ($item=~/[fd]/) {
		$set_var = "($property_type)PyFloat_AsDouble(value)";
	}
	else {
		die "Unsupported type: $property_type ($item)";
	}
	
	print { $self->class->cch } <<PROP;
static PyObject* $getter_name($class_name* python_self, void* python_closure) {
	$pre_get
	return Py_BuildValue("$item", $get_var);
}

static int $setter_name($class_name* self, PyObject* value, void* closure) {
	$pre_set
	self->cpp_object->$property_name = $set_var;
	return 0;	// really should be doing some kind of checking here
}

PROP
	
	push @{ $self->class->{property_table } }, qq({ "$property_name", (getter)$getter_name, (setter)$setter_name, "<DOC>", NULL});
}

1;
