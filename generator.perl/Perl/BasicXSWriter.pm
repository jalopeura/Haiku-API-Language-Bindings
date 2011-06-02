package Perl::ClassGenerator;
use strict;

sub write_basic_xs_file {
	my ($self) = @_;
	
	# determine file name and open file
	(my $filename = $self->{def}{target})=~s!::!_!g;
	$filename = "$self->{folder}/$filename.xs";
	$self->verify_path_for_file($filename);
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	# write an intro comment
	print OUT <<INTRO;
#
# Automatically generated file
#

MODULE = $self->{module}	PACKAGE = $self->{def}{target}

INTRO
	
	# splitting this out allows to reuse it for the main class
	$self->write_basic_xs_code(\*OUT);
	
	close OUT;
	
	$self->{basic_xs_filename} = $filename;
}

sub write_basic_xs_code {
	my ($self, $fh) = @_;
	
	my $class_name = $self->{def}{cpp};
	
	# write the XS code
	for my $constructor (@{ $self->{constructors} }) {
		$self->write_basic_xs_constructor($fh, $constructor, $class_name);
	}
	
	if ($self->{destructor}) {
		$self->write_basic_xs_destructor($fh, $class_name);
	}
	
	for my $method (@{ $self->{methods} }) {
		$self->write_basic_xs_method($fh, $method, $class_name);
	}
	
	# basic classes don't implement events, so no need to include them here
	
	for my $property (@{ $self->{properties} }) {
		$self->write_basic_xs_property($fh, $property, $class_name);
	}
	
	for my $constant (@{ $self->{constants} }) {
		$self->write_basic_xs_constant($fh, $constant, $class_name);
	}
}

sub write_basic_xs_constructor {
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
CONSTRUCTOR
	
	$self->xs_method_body($fh, $body, $xs_input_defs, $xs_error_defs, $xs_error_list);
	
	print $fh <<RETURN;
	OUTPUT:
		RETVAL

RETURN
}

sub write_basic_xs_destructor {
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

sub write_basic_xs_method {
	my ($self, $fh, $method, $class_name) = @_;
	
	my $xs_inputs = $method->{params}->xs_inputs;
	my $xs_input_defs = $method->{params}->xs_input_defs;
	my $xs_error_defs = $method->{params}->xs_error_defs;
	my $xs_cpp_inputs = $method->{params}->xs_cpp_inputs;
	my $xs_output_list = $method->{params}->xs_output_list;
	my $xs_error_list = $method->{params}->xs_error_list;
	my $retcount = @$xs_output_list;
	
	# if only one return value, use it
	if ($retcount <= 1) {
		my $rettype = $xs_output_list->[0]{type} || 'void';
		print $fh <<METHOD;
$rettype
${class_name}::$method->{def}{target}$method->{def}{'overload-name'}($xs_inputs)
METHOD
		
		my $body;
		if ($rettype eq 'void') {
			$body = <<METHOD;
	CODE:
		THIS->$method->{def}{cpp}($xs_cpp_inputs);
METHOD
		}
		else {
			my ($builtin, $target) = $self->{def}{generator}{types}->get_builtin($rettype);
			if ($builtin eq 'object_ptr') {
				$body = <<METHOD;
	INIT:
		char* CLASS = "$target";
METHOD
			}
			$body .= <<METHOD;
	CODE:
		RETVAL = THIS->$method->{def}{cpp}($xs_cpp_inputs);
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
	# otherwise, manipulate the stack ourselves
	else {
		print $fh <<METHOD;
void
${class_name}::$method->{def}{target}$method->{def}{'overload-name'}($xs_inputs)
METHOD
		
		my $body = <<METHOD;
	INIT:
		// setup stuff as necessary
	PPCODE:
		THIS->$method->{def}{cpp}($xs_cpp_inputs);
		// do other necessary stuff here
METHOD
		
		$self->xs_method_body($fh, $body, $xs_input_defs, $xs_error_defs, $xs_error_list);
		
		print $fh <<RETURN;
		// put stuff on the stack here

RETURN
	}
}

sub write_basic_xs_property {
	my ($self, $fh, $property, $class_name) = @_;
	
	my $prop_name = $property->{name};
	my $type = $self->{def}{generator}{types}->get_perl_type($property->{type});
	my $svgetter = "Sv$type";
	my $svsetter = 'sv_set' . lc($type);
	
	# this needs to create a new tied scalar
	
	print $fh <<PROPERTY;
MODULE = $self->{module}	PACKAGE = $self->{def}{target}::$prop_name

SV*
FETCH(tie_obj)
		SV* tie_obj;
	INIT:
		SV* cpp_obj_sv;
		$class_name* cpp_obj;
	CODE:
		RETVAL = newSV(0);
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($class_name*)SvIV(cpp_obj_sv);
		$svsetter(RETVAL, cpp_obj->$prop_name);
	OUTPUT:
		RETVAL

void
STORE(tie_obj, value)
		SV* tie_obj;
		SV* value;
	INIT:
		SV* cpp_obj_sv;
		$class_name* cpp_obj;
	CODE:
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($class_name*)SvIV(cpp_obj_sv);
		cpp_obj->$prop_name = ($property->{type})$svgetter(value);

PROPERTY
	
	my $classlen = length("$self->{def}{target}::$prop_name");
	
	print $fh <<PROPERTY;
MODULE = $self->{module}	PACKAGE = $self->{def}{target}

SV*
${class_name}::$property->{name}()
	INIT:
		SV* cpp_obj_sv;
		SV* tie_obj;
		HV* tie_obj_stash;
	CODE:
		RETVAL = newSV(0);
		// make our object into an SV* and make a reference to it
		cpp_obj_sv = newSViv((IV)THIS);	// do I need to make this mortal?
		tie_obj = newRV_noinc(cpp_obj_sv);
		
		// bless the reference into the proper class
		tie_obj_stash = gv_stashpv("$self->{def}{target}::$prop_name", TRUE);
		sv_bless(tie_obj, tie_obj_stash);
		
		// tie the blessed object to the RETVAL scalar
		sv_magic(RETVAL, tie_obj, PERL_MAGIC_tiedscalar, NULL, 0);
	OUTPUT:
		RETVAL

BOOT:
	CvFLAGS(get_cv("$self->{def}{target}::$prop_name", TRUE)) |= CVf_LVALUE;

PROPERTY
}

sub write_basic_xs_constant {
	my ($self, $fh, $constant, $class_name) = @_;
	
	print $fh <<CONSTANT;
SV*
$constant->{name}()
	CODE:
		RETVAL = newSViv($constant->{name});
	OUTPUT:
		RETVAL

CONSTANT
}

sub xs_method_body {
	my ($self, $fh, $body, $input_defs, $error_defs, $error_list) = @_;
		
	print $fh "$input_defs\n" if $input_defs;
	
	print $fh <<ERROR if $error_defs;
	INIT:
		SV* error_sv;
$error_defs
ERROR
	
	print $fh $body;
	
	$self->xs_error_check($fh, @$error_list);
}

sub xs_error_check {
	my ($self, $fh, @error_params) = @_;
	for my $p (@error_params) {
		print $fh <<ERROR;
		if ($p->{name} != $p->{success}) {
            error_sv = get_sv("$self->{module}::Error", 1);
			sv_setiv(error_sv, (IV)$p->{name});
			XSRETURN_UNDEF;
		}
ERROR
	}
}

#   errsv = get_sv("@", TRUE);
#   sv_setsv(errsv, exception_object);
#   croak(Nullch);

1;

__END__

We need to handle properties by setting 'U' magic on them
Each property needs its own getter/setter/creator
