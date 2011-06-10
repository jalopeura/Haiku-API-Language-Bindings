package Perl::Generator;
use strict;

=pod

generate_xs_method

we should make it generate a single XS sub for all overloaded C++ subs

this will require a lot more work; for now let's use the simpler way

each overloaded function gets passed through once

=cut

sub generate_xs_property {
	my ($self, $fh, %options) = @_;
	
	my $property = $options{property};
	my $cpp_class_name = $options{cpp_class_name};
	my $perl_class_name = $options{perl_class_name};
	my $perl_module_name = $options{perl_module_name};
	
	my $name = $property->{name};
	my $type = $property->{type};
	my $svgetter = $self->{types}->input_converter($type, "cpp_obj->$name", 'value');
	my $svsetter = $self->{types}->output_converter($type, "cpp_obj->$name", 'RETVAL');
	
	print $fh <<PROP;
MODULE = $perl_module_name	PACKAGE = ${perl_class_name}::$name

SV*
FETCH(tie_obj)
		SV* tie_obj;
	INIT:
		SV* cpp_obj_sv;
		$cpp_class_name* cpp_obj;
	CODE:
		RETVAL = newSV(0);
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($cpp_class_name*)SvIV(cpp_obj_sv);
		$svsetter;
	OUTPUT:
		RETVAL

void
STORE(tie_obj, value)
		SV* tie_obj;
		SV* value;
	INIT:
		SV* cpp_obj_sv;
		$cpp_class_name* cpp_obj;
	CODE:
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($cpp_class_name*)SvIV(cpp_obj_sv);
		$svgetter

MODULE = $perl_module_name	PACKAGE = $perl_class_name

SV*
${cpp_class_name}::$name()
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
		tie_obj_stash = gv_stashpv("${perl_class_name}::$name", TRUE);
		sv_bless(tie_obj, tie_obj_stash);
		
		// tie the blessed object to the RETVAL scalar
		sv_magic(RETVAL, tie_obj, PERL_MAGIC_tiedscalar, NULL, 0);
	OUTPUT:
		RETVAL

BOOT:
	CvFLAGS(get_cv("${perl_class_name}::$name", TRUE)) |= CVf_LVALUE;

PROP
}

1;

__END__



MODULE = Haiku::ApplicationKit	PACKAGE = Haiku::Message::what

SV*
FETCH(tie_obj)
		SV* tie_obj;
	INIT:
		SV* cpp_obj_sv;
		BMessage* cpp_obj;
	CODE:
		RETVAL = newSV(0);
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = (BMessage*)SvIV(cpp_obj_sv);
		sv_setuv(RETVAL, cpp_obj->what);
	OUTPUT:
		RETVAL

void
STORE(tie_obj, value)
		SV* tie_obj;
		SV* value;
	INIT:
		SV* cpp_obj_sv;
		BMessage* cpp_obj;
	CODE:
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = (BMessage*)SvIV(cpp_obj_sv);
		cpp_obj->what = (uint32)SvUV(value);

MODULE = Haiku::ApplicationKit	PACKAGE = Haiku::Message

SV*
BMessage::what()
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
		tie_obj_stash = gv_stashpv("Haiku::Message::what", TRUE);
		sv_bless(tie_obj, tie_obj_stash);
		
		// tie the blessed object to the RETVAL scalar
		sv_magic(RETVAL, tie_obj, PERL_MAGIC_tiedscalar, NULL, 0);
	OUTPUT:
		RETVAL

BOOT:
	CvFLAGS(get_cv("Haiku::Message::what", TRUE)) |= CVf_LVALUE;