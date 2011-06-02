package PerlGenerator;
use PerlParams;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
}

sub start_binding {
	my ($self, $infile, $outfolder) = @_;
	my ($package) = $infile=~m:([^/]+)\.def$:g;
	
	mkdir "$outfolder/perl" unless -e "$outfolder/perl";
	
	$self->{folder} =  "$outfolder/perl/$package";
	mkdir $self->{folder} unless -e $self->{folder};
	
	open $self->{h_fh}, ">$self->{folder}/$package.h" or die "Unable to create file '$self->{folder}/$package.h': $!";
	print { $self->{h_fh} } <<TOP;
/*
Automatically generated file for creating Perl bindings for the Haiku API
*/
TOP
	
	open $self->{cpp_fh}, ">$self->{folder}/$package.cpp" or die "Unable to create file '$self->{folder}/$package.cpp': $!";
	print { $self->{cpp_fh} } <<TOP;
/*
Automatically generated file for creating Perl bindings for the Haiku API
*/
#include "$package.h";

void PerlObject::make_perl_object(IV cpp_obj_pointer, const char* perl_class_name, bool must_not_delete) {
	HV* underlying_hash;
	SV* cpp_obj_sv;
	IV  no_delete;
	SV* no_delete_sv;
	SV* perl_obj;
	HV* stash;
	
	// create the hash
	underlying_hash = newHV();
	
	//store the C++ object
	cpp_obj_sv = newSViv(cpp_obj_pointer);
	SvREADONLY_on(cpp_obj_sv);	// not sure this does any good; can't perl code just assign a new SV* to this key?
	hv_store(underlying_hash, "_cpp_obj", 8, cpp_obj_sv, 0);
	
	//store the must_not_delete value
	no_delete = bool_must_not_delete ? 1 : 0;
	no_delete_sv = newSViv(no_delete);
	SvREADONLY_on(no_delete_sv);	// not sure this does any good; can't perl code just assign a new SV* to this key?
	hv_store(underlying_hash, "_must_not_delete", 16, no_delete_sv, 0);
	
	// create a reference
	perl_obj = newRV_noinc((SV*) underlying_hash);
	
	// get the stash for the perl class
	stash = gv_stashpv(perl_class_name, TRUE);
	
	// bless the reference
	sv_bless(perl_obj, stash);
	
	return perl_obj;
}

TOP
	
	open $self->{xs_fh}, ">$self->{folder}/$package.xs" or die "Unable to create file '$self->{folder}/$package.xs': $!";
	print { $self->{xs_fh} } <<TOP;
/*
Automatically generated file for creating Perl bindings for the Haiku API
*/
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

TOP
}

sub end_binding {
	my ($self, $infile, $outfolder) = @_;
	
	close $self->{cpp_fh};
	close $self->{xs_fh};
}

sub bundle {
	my ($self, $bundle) = @_;
	$self->{bundle} = $bundle;
}

sub include {
	my ($self, @files) = @_;
	for my $f (@files) {
		print { $self->{h_fh} } qq(#include <$f>\n);
	}
	print { $self->{h_fh} } "\n";
}

sub start_class {
	my ($self, %params) = @_;
	my ($class) = $params{target}=~/([^:]+)$/;
	$self->{prefix} = $class;
	$self->{current_class} = "Perl$class";
	$self->{current_parent} = $params{cpp};
	$self->{perl_class} = $params{target};
	$self->{properties} = [];
	
	unless ($self->{perl_object_defined}) {
		print { $self->{h_fh} } <<PERL_OBJ;
class PerlObject {
	public:
		static void make_perl_object(IV cpp_obj_pointer, const char* perl_class_name, bool must_not_delete = false);
		SV*	perl_obj;
}

PERL_OBJ
		$self->{perl_object_defined} = 1;
	}
	
	print { $self->{h_fh} } <<CLASS;
class $self->{current_class} : public $self->{current_parent}, public PerlObject {
	public:
CLASS

	print { $self->{xs_fh} } <<CLASS;
MODULE = $self->{bundle}	PACKAGE = $self->{perl_class}

CLASS
}

sub end_class {
	my ($self, %params) = @_;
	my ($class) = $params{target}=~/([^:]+)$/;

	for my $p (@{ $self->{properties} }) {
		my $getter = 'get_' . $p->{name} . '_sv';
		my $setter = 'set_' . $p->{name} . '_sv';
		
		print { $self->{h_fh} } <<PROPERTY;
		static I32 $getter(IV index, SV* magic_$p->{name});
		static I32 $setter(IV index, SV* magic_$p->{name});
		SV* magic_$p->{name}();
PROPERTY
		
		print { $self->{cpp_fh} } <<PROPERTY;
I32 $self->{current_class}::$getter(IV index, SV* magic_$p->{name}) {
	$self->{current_class}* obj = ($self->{current_class}*)index;	// not sure this is the right way to do this
	svget(magic_$p->{name}, obj->$p->{name});	// not sure this is the right way to do this
}

I32 $self->{current_class}::$setter(IV index, SV* magic_$p->{name}) {
	$self->{current_class}* obj = ($self->{current_class}*)index;	// not sure this is the right way to do this
	svset(magic_$p->{name}, obj->$p->{name});	// not sure this is the right way to do this
}

SV* $self->{current_class}::magic_$p->{name}() {
	SV* magic_$p->{name};
	struct ufuncs uf;
	
	uf.uf_val = &getter;
	uf.uf_set = &setter;
	uf.uf_index = (IV)this;	// not sure this is the right way to do this
	sv_magic(magic_$p->{name}, 0, 'U', (char*)&uf, sizeof(uf));
	
	return magic_$p->{name};
}

PROPERTY
		
		print { $self->{xs_fh} } <<PROPERTY;
SV*
$self->{current_class}::$p->{name}()
	CODE:
		RETVAL = THIS->magic_$p->{name};
	OUTPUT:
		RETVAL

PROPERTY
	}

	print { $self->{h_fh} } <<END;
} // $self->{current_class}

END
	
	undef $self->{current_class};
}

sub xs_error_check {
	my ($self, @error_params) = @_;
	for my $p (@error_params) {
		print { $self->{xs_fh} } <<ERROR;
		if ($p->{name} != $p->{success}) {
			RETVAL = undef;	// is this the right way to make it undef? probably not
			// here we need to put the warning in the right place
		}
ERROR
	}
}

sub property {
	my ($self, %property) = @_;
	push @{ $self->{properties} }, \%property;
}

sub constructor {
	my ($self, $attrs, @params) = @_;
	
	my $params = new Params(@params);
	
	my $h_params = $params->h_params;
	print { $self->{h_fh} } <<CONSTRUCTOR;
		$self->{current_class}($h_params);
CONSTRUCTOR
	
	my $cpp_params = $params->cpp_params;
	print { $self->{cpp_fh} } <<CONSTRUCTOR;
$self->{current_class}::$self->{current_class}($cpp_params)
	: $self->{current_parent}($cpp_params) {}

CONSTRUCTOR

	my $xs_inputs = $params->xs_inputs;
	my $xs_input_defs = $params->xs_input_defs;
	my $xs_cpp_inputs = $params->xs_cpp_inputs;
	my $perl_name = 'new' . $attrs->{overload-name};
	print { $self->{xs_fh} } <<CONSTRUCTOR;
$self->{current_class}*
$self->{current_class}::new$attrs->{'overload-name'}($xs_inputs)
$xs_input_defs
	CODE:
		RETVAL = new $self->{current_class}($xs_cpp_inputs);
CONSTRUCTOR
	
	my $xs_error_list = $params->xs_error_list;
	$self->xs_error_check(@$xs_error_list);
	
	print { $self->{xs_fh} } <<RETURN;
		RETVAL->perl_obj = PerlObject::make_perl_object((IV)RETVAL, "$self->{perl_class}");
	OUTPUT:
		RETVAL

RETURN
}

sub destructor {
	my ($self) = @_;
	
	print { $self->{h_fh} } <<DESTRUCTOR;
		~$self->{current_class}();
DESTRUCTOR
	
	print { $self->{cpp_fh} } <<DESTRUCTOR;
$self->{current_class}::~$self->{current_class}() {}

DESTRUCTOR
	
	print { $self->{xs_fh} } <<DESTRUCTOR;
void
$self->{current_class}::DESTROY()
	INIT:
		SV*  underlying_obj_hash;
		SV** ptr_to_must_not_delete_sv;
	PPCODE:
		underlying_obj_hash = (HV*)SvRV(THIS->perl_obj);
		ptr_to_must_not_delete_sv = hv_fetch(underlying_obj_hash, "_must_not_delete", 16, 0);
		if (! SvTRUE(*ptr_to_must_not_delete_sv) {
			delete THIS;
		}

DESTRUCTOR
}

sub method {
	my ($self, $attrs, $return, @params) = @_;
	
	$self->method_or_event(0, $attrs, $return, @params);
}

sub event {
	my ($self, $attrs, $return, @params) = @_;
	
	$self->method_or_event(1, $attrs, $return, @params);
}

sub method_or_event {
	my ($self, $is_event, $attrs, $return, @params) = @_;
	
	my $params = new Params(@params);
	$params->parse($return, 1);
	
	# just inherit methods, but re-implement events
	if ($is_event) {
		my $h_params = $params->h_params;
		print { $self->{h_fh} } <<EVENT;
		$attrs->{'cpp-name'}($h_params);
EVENT
		

#EXTEND(SP, int i);	# where i is the number of arguments on the stack
#PUSHMARK(SP);
#PUSHs(sv_2mortal(newSVnv(<some value>)));	# first value must be the perl object ref; other values as needed
#PUTBACK;
#call_method(method, G_DISCARD);
		
		my $cpp_params = $params->cpp_params;
		my $perl_event_params = $params->perl_event_params;
		my $perl_event_param_count = $params->perl_event_param_count;
			$perl_event_param_count++;	# add one for the perl object itself
		my $perl_event_param_defs = $params->perl_event_param_defs;
		print { $self->{cpp_fh} } <<EVENT;
$self->{current_class}::$attrs->{'cpp-name'}($cpp_params) {
$perl_event_param_defs
	EXTEND(SP, $perl_event_param_count);
	PUSHMARK(SP);
	PUSHs(this->perl_obj);
$perl_event_params
	PUTBACK;
	call_method("$attrs->{'cpp-name'}", G_DISCARD);
}

EVENT
	}

	my $perl_name = $attrs->{cpp-name} . $attrs->{overload-name};
	
#	my $this_obj = $is_event ? "(($self->{current_parent}*)THIS)" : 'THIS';
	my $this_obj = 'THIS';
	
	my $xs_inputs = $params->xs_inputs;
	my $xs_input_defs = $params->xs_input_defs;
	my $xs_cpp_inputs = $params->xs_cpp_inputs;
	my $xs_output_list = $params->xs_output_list;
	my $xs_error_list = $params->xs_error_list;
	my $retcount = @$xs_output_list;
	# if only one return value, use it
	if ($retcount <= 1) {
		my $rettype = $params{perl_output_list}[0]{type} || 'void';
		print { $self->{xs_fh} } <<METHOD;
$rettype
$self->{current_parent}::$attrs->{'cpp-name'}$attrs->{'overload-name'}($xs_inputs)
METHOD
		
		print  { $self->{xs_fh} } "$xs_input_defs\n" if $xs_input_defs;
		
		print { $self->{xs_fh} } <<METHOD;
	CODE:
		RETVAL = ${this_obj}->$attrs->{'cpp-name'}($xs_cpp_inputs);
METHOD
		
		$self->xs_error_check(@$xs_error_list);
		
		if ($retcount) {
			print { $self->{xs_fh} } <<RETURN;
	OUTPUT:
		RETVAL
RETURN
		}
		print { $self->{xs_fh} } "\n";
	}
	else {
		print { $self->{xs_fh} } <<METHOD;
void
$self->{current_parent}::$attrs->{'cpp-name'}$attrs->{'overload-name'}($xs_inputs)
METHOD
		
		print  { $self->{xs_fh} } "$params{perl_input_defs}\n" if $params{perl_input_defs};
		
		print { $self->{xs_fh} } <<METHOD;
	INIT:
		// setup stuff as necessary
	PPCODE:
		${this_obj}->$attrs->{'cpp-name'}($xs_cpp_inputs);
		// do other necessary stuff here
METHOD
		
		$self->xs_error_check(@{ $params{perl_error_list} });
		
		print { $self->{xs_fh} } <<RETURN;
		// put stuff on the stack here

RETURN
	}
}

1;

__END__

Okay, to create a perl object we must
1) Create a hashref
2) bless it into a particular class
3) cast the c++ object to an int and make it a readonly element in the hash

to get the hash back:
    SV* dereferenced_pointer = SvRV(ref_pointer)
	hash = (HV*) dereferenced_pointer

SvREADONLY_on(sv)

sv_bless
    Blesses an SV into a specified package. The SV must be an RV. The package must be designated by its stash (see gv_stashpv()). The reference count of the SV is unaffected.

            SV*     sv_bless(SV* sv, HV* stash)

gv_stashpv
    Returns a pointer to the stash for a specified package. name should be a valid UTF-8 string. If create is set then the package will be created if it does not already exist. If create is not set and the package does not exist then NULL is returned.

            HV*     gv_stashpv(const char* name, I32 create)



gv_fetchmeth
    Returns the glob with the given name and a defined subroutine or NULL. The glob lives in the given stash, or in the stashes accessible via @ISA and @UNIVERSAL.

    The argument level should be either 0 or -1. If level==0, as a side-effect creates a glob with the given name in the given stash which in the case of success contains an alias for the subroutine, and sets up caching info for this glob. Similarly for all the searched stashes.

    This function grants "SUPER" token as a postfix of the stash name. The GV returned from gv_fetchmeth may be a method cache entry, which is not visible to Perl code. So when calling call_sv, you should not use the GV directly; instead, you should use the method's CV, which can be obtained from the GV with the GvCV macro.

            GV*     gv_fetchmeth(HV* stash, const char* name, STRLEN len, I32 level)


CV* GvCV(GV*)

EXTEND(SP, int i);	# where i is the number of arguments on the stack
PUSHMARK(SP);
PUSHs(sv_2mortal(newSVnv(<some value>)));	# first value must be the perl object ref; other values as needed
PUTBACK;
call_method(method, G_DISCARD);

# for each class described
# create an XS file; this should include whatever files are necessary
# if there are events, create an H file and a CPP file with a new responder class
#    as well as an XS file for this responder class
