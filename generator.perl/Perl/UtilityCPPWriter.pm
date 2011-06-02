package Perl::Generator;
use strict;

sub write_utility_cpp_file {
	my ($self) = @_;
	
	my $filename = "$self->{folder}/$self->{package}Utils.cpp";
	my ($hfile) = $self->{package}=~m/([^:]+)$/;
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	# write an intro comment
	print OUT <<INTRO;
/*
 *Automatically generated file for creating Perl bindings for the Haiku API
 */

#include "${hfile}Utils.h"

SV* create_perl_object(IV cpp_obj_address, const char* perl_class_name, bool must_not_delete) {
	HV* visible_hash;
	SV* perl_obj;
	HV* hidden_hash;
	SV* cpp_obj_sv;
	IV  can_delete;
	SV* can_delete_sv;
	HV* perl_obj_stash;
//SV** check;
	
	// create the visible hash and make a ref to it
	visible_hash = newHV();
	perl_obj = newRV_noinc((SV*) visible_hash);
	
	// create the hidden hash and link them via ~ magic
	hidden_hash = newHV();
	sv_magic((SV*)visible_hash, (SV*)hidden_hash, '~', NULL, 0);	// will the reference count be incremented by this function?
	
	// get the perl object's stash and bless the hash into it
	perl_obj_stash = gv_stashpv(perl_class_name, TRUE);
	sv_bless(perl_obj, perl_obj_stash);
	
	// store the cpp object's address in the hidden hash
	cpp_obj_sv = newSViv(cpp_obj_address);	// do I need to make this mortal?
	/*check = */hv_store(hidden_hash, "_cpp_obj", 8, cpp_obj_sv, 0);
//	if (check == NULL)
//		warn("%s", "Failed to store _cpp_obj");
	
	//store the must_not_delete value in the hidden hash
	can_delete = must_not_delete ? 0 : 1;
	can_delete_sv = newSViv(can_delete);
	/*check = */hv_store(hidden_hash, "_can_delete", 11, can_delete_sv, 0);
//	if (check == NULL)
//		warn("%s", "Failed to store _can_delete");
//warn("H: %d", (IV)hidden_hash);
//warn("U: %d", (IV)visible_hash);
	
	// get the stash and bless the ref (to the visible hash) into it
	perl_obj_stash = gv_stashpv(perl_class_name, TRUE);
	sv_bless(perl_obj, perl_obj_stash);
	
	return perl_obj;
}

HV* get_hidden_hash(SV* perl_obj) {
	SV* underlying_hash;
	MAGIC* mg;
	HV* hidden_hash;
	
	// get the underlying hash that the perl_obj is a reference to
	// (we can leave it an SV* because we're just using it to find magic)
	underlying_hash = SvRV(perl_obj);
//warn("U: %d", (IV)underlying_hash);
	
	// get the hidden hash linked to the perl_obj
	mg = mg_find(underlying_hash, '~');
	hidden_hash = (HV*)mg->mg_obj;
//warn("H: %d", (IV)hidden_hash);
	
	return hidden_hash;
}

void delete_perl_object(SV* perl_obj) {
	HV* hidden_hash;
	
	// get the hidden hash linked to the perl_obj
	hidden_hash = get_hidden_hash(perl_obj);
	
	// remove the magical link
	sv_unmagic((SV*)hidden_hash, '~');
	
	// TODO: make sure all the reference counts for hidden_hash and visible hash go to 0
}

void update_must_not_delete(SV* perl_obj, bool must_not_delete) {
	HV* hidden_hash;
	IV can_delete;
	SV** can_delete_sv;
	
	// get the hidden hash linked to the perl_obj
	hidden_hash = get_hidden_hash(perl_obj);
	
	// update the value
	can_delete = must_not_delete ? 0 : 1;
	can_delete_sv = hv_fetch(hidden_hash, "_can_delete", 11, 0);
	sv_setiv(*can_delete_sv, can_delete);
//	hv_store(hidden_hash, "_can_delete", 11, *can_delete_sv, 0);
}

IV extract_cpp_object(SV* perl_obj) {
	HV* hidden_hash;
	SV** value;
	IV cpp_obj_address;
	
	// get the hidden hash linked to the perl_obj
	hidden_hash = get_hidden_hash(perl_obj);
	
	// get the "_cpp_obj" value from that hash
	value = hv_fetch(hidden_hash, "_cpp_obj", 8, 0);
	cpp_obj_address = SvIV(*value);
	
	return cpp_obj_address;
}

bool can_delete_cpp_object(SV* perl_obj) {
	MAGIC* mg;
	SV* visible_hash;
	HV* hidden_hash;
	SV** value;
	bool can_delete = false;
	
	// get the hidden hash linked to the perl_obj
	hidden_hash = get_hidden_hash(perl_obj);
	
	
	// get the "_can_delete" value from that hash
	value = hv_fetch(hidden_hash, "_can_delete", 11, 0);
//	if (value == NULL)
//		warn("%s", "NULL returned from hv_fetch");
	
	return can_delete;
}

/*
 * getters/setters/wrappers for properties
 */

INTRO
	
	# getters/setters/wrappers for properties
	if ($self->{classes}) {
		for my $class (@{ $self->{classes} }) {
			next unless $class->{properties};
			my $class_name = $class->{def}{cpp};
			for my $p (@{ $class->{properties} }) {
				my $prop_name = $p->{name};
				my $type = $self->{types}->get_perl_type($p->{type});
				my $svgetter = "Sv$type";
				my $svsetter = 'sv_set' . lc($type);
				print OUT <<PROPERTY;
// ${class_name}::${prop_name}

I32 get_${class_name}_${prop_name}(IV index, SV* magic_$prop_name) {
	$class_name* obj = ($class_name*)index;	// not sure this is the right way to do this
warn("Getting magic $prop_name: %f", obj->$prop_name);
	$svsetter(magic_$prop_name, obj->$prop_name);	// not sure this is the right way to do this
}

I32 set_${class_name}_${prop_name}(IV index, SV* magic_$prop_name) {
	$class_name* obj = ($class_name*)index;	// not sure this is the right way to do this
warn("Setting magic $prop_name: %f", (float)SvNV(magic_$prop_name));
	obj->$prop_name = ($p->{type})$svgetter(magic_$prop_name);	// not sure this is the right way to do this
}

SV* create_${class_name}_${prop_name}($class_name* obj) {
	SV* magic_$prop_name;
	struct ufuncs uf;
	
	uf.uf_val = &get_${class_name}_${prop_name};
	uf.uf_set = &set_${class_name}_${prop_name};
	uf.uf_index = (IV)obj;	// not sure this is the right way to do this
	sv_magic(magic_$prop_name, 0, 'U', (char*)&uf, sizeof(uf));
warn("Creating magic $prop_name: %f", (float)SvNV(magic_$prop_name));
	
	return magic_$prop_name;
}

PROPERTY
			}
		}
	}
	
	close OUT;
}

1;
