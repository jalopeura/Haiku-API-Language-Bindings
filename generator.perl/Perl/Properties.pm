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

sub type {
	my ($self) = @_;
	unless ($self->{type}) {
		my $t = $self->{type_name};
		if ($self->{needs_deref}) {
			$t=~s/\*$//;
		}
		$self->{type} = $self->types->type($t);
	}
	return $self->{type};
}

sub input_converter {
	my ($self, $target) = @_;
	
	if ($self->has('repeat')) {
		return $self->type->array_input_converter("cpp_obj->$self->{name}", $target, $self->repeat);
	}
	
	return [ $self->type->input_converter("cpp_obj->$self->{name}", $target) ];
}

sub output_converter {
	my ($self, $target) = @_;
	
	if ($self->has('repeat')) {
		return $self->type->array_output_converter("cpp_obj->$self->{name}", $target, $self->repeat, 1);	# 1 (true) because we should never delete a property
	}
	
	return [ $self->type->output_converter("cpp_obj->$self->{name}", $target, 1) ];	# 1 (true) because we should never delete a property
}

sub generate {
	my ($self) = @_;
	
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	my $name = $self->name;
	my $ctype_to_sv = $self->output_converter('RETVAL');
	my $sv_to_ctype = $self->input_converter('value');
	
	my $fh = $self->package->xsh;
	
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
PROP
	
	for my $line (@$ctype_to_sv) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<PROP;
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
PROP
	
	for my $line (@$sv_to_ctype) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<PROP;

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
