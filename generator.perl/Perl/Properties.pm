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

sub is_array_or_string {
	my ($self) = @_;
	
	if ($self->has('array_length') or
		$self->has('string_length') or
		$self->has('max_array_length') or
		$self->has('max_string_length')) {
		return 1;
	}
	
	my $type = $self->type;
	if ($type->has('array_length') or
		$type->has('string_length') or
		$type->has('max_array_length') or
		$type->has('max_string_length')) {
		return 1;
	}
	
	return undef;
}

sub input_converter {
	my ($self, $target) = @_;
	
	my $options = {
		input_name => $target,
		output_name => 'cpp_obj->' . $self->name,
		self_name => 'cpp_obj',
		must_not_delete => 1,	# never try to delete a property
	};
	for my $x (qw(array_length string_length max_array_length max_string_length)) {
		if ($self->has($x)) {
			$options->{$x} = $self->{$x};
			if ($self->{$x}=~/SELF\./) {
				$options->{"set_$x"} = 1;
			}
		}
	}
	
	return $self->type->input_converter($options);
}

sub output_converter {
	my ($self, $target) = @_;
	
	my $options = {
		input_name => 'cpp_obj->' . $self->name,
		output_name => $target,
		self_name => 'cpp_obj',
		must_not_delete => 1,	# never try to delete a property
	};
	for my $x (qw(array_length string_length max_array_length max_string_length)) {
		if ($self->has($x)) {
			$options->{$x} = $self->{$x};
		}
	}
	
	return $self->type->output_converter($options);
}

sub generate {
	my ($self) = @_;
	
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	my $name = $self->name;
	my ($fetch_defs, $fetch_code) = $self->output_converter('RETVAL');
	my ($store_defs, $store_code) = $self->input_converter('value');
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
PROP
	
	for my $line (@$fetch_defs) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<PROP;
		RETVAL = newSV(0);
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($cpp_class_name*)SvIV(cpp_obj_sv);
PROP
	
	for my $line (@$fetch_code) {
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
PROP
	
	for my $line (@$store_defs) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<PROP;
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($cpp_class_name*)SvIV(cpp_obj_sv);
PROP
	
	for my $line (@$store_code) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<PROP;

MODULE = $perl_module_name	PACKAGE = $perl_class_name

# Some structs must be prefaced with the keyword 'struct' or gcc 
# complains. Unfortunately, if you put 'struct' in the XSub def,
# xsubpp can't parse the type, and if you don't, xsubpp complains
# about the non-'struct' version not being in the typemap. So we
# get the THIS variable ourselves in the property XSub instead of
# prefixing the XSub name as '$cpp_class_name\::$name'

SV*
$name(THIS)
	INPUT:
		$cpp_class_name* THIS;
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
