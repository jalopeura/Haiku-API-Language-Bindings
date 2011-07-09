use Common::Properties;
use Perl::BaseObject;

package Perl::Properties;
use strict;
our @ISA = qw(Properties Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('properties')) {
		for my $p ($self->properties) {
			$p->generate;
		}
	}
}

package Perl::Property;
use strict;
our @ISA = qw(Property Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	my $name = $self->name;
	my $type = $self->types->type($self->type);
	my $svgetter = $type->input_converter("cpp_obj->$name", 'value');
	my $svsetter = $type->output_converter("cpp_obj->$name", 'RETVAL');
	
	print { $self->package->xsh } <<PROP;
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
