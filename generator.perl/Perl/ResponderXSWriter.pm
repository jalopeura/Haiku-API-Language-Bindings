package Perl::ClassGenerator;
use strict;

sub write_responder_xs_file {
	my ($self, $def) = @_;
	
	# determine file name and open file
	(my $filename = $def->{target})=~s!::!_!g;
	$filename = "$self->{folder}/$filename.xs";
	$self->verify_path_for_file($filename);
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	my $class_name = $def->{cpp};
	my $parent_class_name = $self->{def}{cpp};
	
	# write an intro comment
	print OUT <<INTRO;
#
# Automatically generated file
#

MODULE = $self->{module}	PACKAGE = $def->{target}

INTRO
	
	# write the XS code
	for my $constructor (@{ $self->{constructors} }) {
		$self->write_responder_xs_constructor(\*OUT, $constructor, $class_name);
	}
	
	if ($self->{destructor}) {
		$self->write_responder_xs_destructor(\*OUT, $class_name);
	}
	
	# responder classes inherit the methods, so no need to define them here
	
	for my $event (@{ $self->{events} }) {
		$self->write_responder_xs_event(\*OUT, $event, $class_name, $parent_class_name);
	}
	
	close OUT;
	
	$self->{responder_xs_filename} = $filename;
}

sub write_responder_xs_constructor {
	my ($self, $fh, $constructor, $class_name) = @_;

	my $xs_inputs = $constructor->{params}->xs_inputs;
	my $xs_input_defs = $constructor->{params}->xs_input_defs;
	my $xs_error_defs = $constructor->{params}->xs_error_defs;
	my $xs_cpp_inputs = $constructor->{params}->xs_cpp_inputs;
	my $xs_error_list = $constructor->{params}->xs_error_list;
	my $perl_name = 'new' . $constructor->{def}{'overload-name'};
	
	# we need to trick xsubpp into making this a constructor
	my $xs_method_name;
	if ($perl_name ne 'new') {
		$xs_method_name = $perl_name;
		if ($xs_inputs) {
			$xs_inputs = "CLASS, $xs_inputs";
		}
		else {
			$xs_inputs = "CLASS";
		}
		if ($xs_input_defs) {
			$xs_input_defs = "\t\tchar* CLASS\n$xs_input_defs";
		}
		else {
			$xs_input_defs = "\t\tchar* CLASS";
		}
		print $fh <<COMMENT;
# Note that this method is not prefixed by the class name.
#
# This is because for prefixed methods, xsubpp will turn the first perl
# argument into the CLASS variable (a char*) if the method name is 'new',
# and into the THIS variable (the object pointer) otherwise. So we need to
# trick xsubbpp by leaving off the prefix and generating CLASS ourselves
COMMENT
	}
	else {
		$xs_method_name = "${class_name}::$perl_name";
	}
	
	# write the constructor
	print $fh <<CONSTRUCTOR;
$class_name*
$xs_method_name($xs_inputs)
CONSTRUCTOR
	
	my $body = <<CONSTRUCTOR;
	CODE:
		RETVAL = new $class_name($xs_cpp_inputs);
		RETVAL->perl_obj = create_perl_object((IV)RETVAL, CLASS, false);
CONSTRUCTOR
	
	$self->xs_method_body($fh, $body, $xs_input_defs, $xs_error_defs, $xs_error_list);
	
	print $fh <<RETURN;
	OUTPUT:
		RETVAL

RETURN
}

sub write_responder_xs_destructor {
	my ($self, $fh, $class_name) = @_;
	
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
	SV* perl_obj = \$arg;
	INIT:
		IV cpp_obj_address;
		$class_name* cpp_obj;
	CODE:
		if (can_delete_cpp_object(perl_obj)) {
			cpp_obj_address = extract_cpp_object(perl_obj);
			cpp_obj = ($class_name*)cpp_obj_address;
			delete cpp_obj;
		}
		delete_perl_object(perl_obj);

DESTRUCTOR
}

sub write_responder_xs_event {
	my ($self, $fh, $event, $class_name, $parent_class_name) = @_;
	
	my $xs_inputs = $event->{params}->xs_inputs;
	my $xs_input_defs = $event->{params}->xs_input_defs;
	my $xs_error_defs = $event->{params}->xs_error_defs;
	my $xs_cpp_inputs = $event->{params}->xs_cpp_inputs;
	my $xs_output_list = $event->{params}->xs_output_list;
	my $xs_error_list = $event->{params}->xs_error_list;
	my $retcount = @$xs_output_list;
	
	my $rettype = $xs_output_list->[0]{type} || 'void';
	print $fh <<METHOD;
$rettype
${class_name}::$event->{def}{target}$event->{def}{'overload-name'}($xs_inputs)
METHOD
	
	my $body;
	if ($rettype eq 'void') {
		$body = <<METHOD;
	CODE:
		THIS->${parent_class_name}::$event->{def}{cpp}($xs_cpp_inputs);
METHOD
	}
	else {
		$body = <<METHOD;
	CODE:
	RETVAL = THIS->${parent_class_name}::$event->{def}{cpp}($xs_cpp_inputs);
METHOD
	}
	
	$self->xs_method_body($fh, $body, $xs_input_defs, $xs_error_defs, $xs_error_list);
	
	if ($retcount and $rettype ne 'void') {
		print $fh <<RETURN;
OUTPUT:
	RETVAL
RETURN
	}
	print $fh "\n";
}

1;

