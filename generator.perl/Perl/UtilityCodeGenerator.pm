package Perl::Module;
use strict;

sub generate_utility_h_code {
	my ($self, $folder) = @_;
	
	my $filename = File::Spec->catfile($folder, "$self->{filename}.h");
	open my $fh, ">$filename" or die "Unable to create file '$filename': $!";
	
	print $fh <<TOP;
/*
 * Automatically generated file
 */
 
TOP
	
	if ($self->{includes}) {
		for my $file (@{ $self->{includes} }) {
			print $fh "#include <$file>\n";
		}
		print $fh "\n";
	}
	
	print $fh <<UTIL;
// comment this out to disallow debugging
#define DEBUGOK

#ifdef DEBUGOK
#define DEBUGME(LEVEL, PATTERN, ...) debug_me(LEVEL, __FILE__, __LINE__, PATTERN, ##__VA_ARGS__)
#else
#define DEBUGME(LEVEL, PATTERN, ...)
#endif

int debug_level = 0;

void debug_me(int level, const char* file, int line, const char* pattern, ...);
void set_up_debug_sv();

struct object_link_data {
	void* cpp_object;
	SV*   perl_object;
	bool  can_delete_cpp_object;
};

SV* create_perl_object(void* cpp_obj_address, const char* perl_class_name);
object_link_data* get_link_data(SV* perl_obj);
void unlink_perl_object(SV* perl_obj);
void must_not_delete_cpp_object(SV* perl_obj, bool must_not_delete);
void* get_cpp_object(SV* perl_obj);
bool can_delete_cpp_object(SV* perl_obj);

char** Aref2CharArray(SV* arg, int &count);
SV* CharArray2Aref(char** var, int count);

UTIL
	
	close $fh;
}

sub generate_utility_cpp_code {
	my ($self, $folder) = @_;
	
	my $filename = File::Spec->catfile($folder, "$self->{filename}.cpp");
	open my $fh, ">$filename" or die "Unable to create file '$filename': $!";
	
	print $fh <<UTIL;
/*
 * Automatically generated file
 */
 
#include "$self->{filename}.h"
 	
void set_up_debug_sv(const char* name) {
	SV* tie_obj;
	HV* tie_obj_stash;
	
	// create an sv and make it a reference to another (new and empty) sv
	tie_obj = newSV(0);
	newSVrv(tie_obj, NULL);
		
	// bless the reference into the name'd class
	tie_obj_stash = gv_stashpv(name, TRUE);
	sv_bless(tie_obj, tie_obj_stash);
		
	// tie the blessed object to the name'd scalar
	sv_magic(get_sv(name, 1), tie_obj, PERL_MAGIC_tiedscalar, NULL, 0);
}

void debug_me(int level, const char* file, int line, const char* pattern, ...) {
	if (! (debug_level & level))
		return;
	
	va_list args;
	va_start(args, pattern);
	vwarn(pattern, &args);
	va_end(args);
	
	warn("\\t...generated by %s line %d\\n", file, line);
}

SV* create_perl_object(void* cpp_obj, const char* perl_class_name) {
	HV* underlying_hash;
	SV* perl_obj;
	HV* perl_obj_stash;
	object_link_data* link = new object_link_data;
		
	// create the underlying hash and make a ref to it
	underlying_hash = newHV();
	perl_obj = newRV_noinc((SV*) underlying_hash);
	
	// get the stash and bless the ref (to the underlying hash) into it
	perl_obj_stash = gv_stashpv(perl_class_name, TRUE);
	sv_bless(perl_obj, perl_obj_stash);
	
	// fill in the data fields
	link->cpp_object = cpp_obj;
	link->perl_object = perl_obj;
	link->can_delete_cpp_object = true;
	
	// link the data via '~' magic
	// (we link to the underlying hash and not to the reference itself)
	sv_magic((SV*)underlying_hash, NULL, PERL_MAGIC_ext, (const char*)link, 0);	// cheat by strong data instead of a string
//	DEBUGME(4, "Created perl object %d of class %s for cpp object %d with link %d", (IV)perl_obj, perl_class_name, (IV)cpp_obj, (IV)link);
	link = get_link_data(perl_obj);
//	DEBUGME(4, "Verifying that setting magic worked: got link object: %d", (IV)link); 
	
	return perl_obj;
}

object_link_data* get_link_data(SV* perl_obj) {
	SV* underlying_hash;
	MAGIC* mg;
//	DEBUGME(4, "Trying to find link data for Perl object: %d", (IV)perl_obj);

	// get the underlying hash that the perl_obj is a reference to
	// (we can leave it an SV* because we're just using it to find magic)
	underlying_hash = SvRV(perl_obj);
	
	// get the data linked to the underlying hash
	mg = mg_find(underlying_hash, PERL_MAGIC_ext);
	if (mg == NULL)
		return NULL;
//	DEBUGME(4, "Found magic with pointer: %d, %d", (IV)mg, (IV)mg->mg_ptr);
	
	return (object_link_data*)mg->mg_ptr;
}

void unlink_perl_object(SV* perl_obj) {
	object_link_data* link;
	
	// get the object linked to the perl_obj
	link = get_link_data(perl_obj);
	
	if (link == NULL)
		return;
	
	// remove the magical link
	sv_unmagic(perl_obj, PERL_MAGIC_ext);
	
	SvREFCNT_dec(link->perl_object);	// decrement reference count
	link->perl_object = NULL;
	
	if (link->perl_object == NULL && link->cpp_object == NULL)
		delete link;
}

void must_not_delete_cpp_object(SV* perl_obj, bool must_not_delete) {
	object_link_data* link;
	
	// get the object linked to the perl_obj
	link = get_link_data(perl_obj);
	
	if (link == NULL)
		return;
	
	// update the value
	link->can_delete_cpp_object = must_not_delete ? false : true;
}

void* get_cpp_object(SV* perl_obj) {
	object_link_data* link;
	
	// get the object linked to the perl_obj
	link = get_link_data(perl_obj);
//	DEBUGME(4, "Got object link data: %d", (IV)link);
	
	if (link == NULL)
		return NULL;
	
	return link->cpp_object;
}

bool can_delete_cpp_object(SV* perl_obj) {
	object_link_data* link;
//	DEBUGME(4, "Checking whether we can delete the cpp object");
	
	// get the object linked to the perl_obj
	link = get_link_data(perl_obj);
	
	if (link == NULL)
		return false;
	
	return link->can_delete_cpp_object;
}

char** Aref2CharArray(SV* arg, int &count) {
	AV* av;
	char** ret;
	int i;
	
	if (!arg || !SvOK(arg) || !SvROK(arg) || (SvTYPE(SvRV(arg)) != SVt_PVAV)) {
		croak("array reference expected");
	}
	
	av = (AV*)SvRV(arg);
	count = av_len(av) + 1;	// av_len returns highest index, not count
	ret = (char**)malloc(av_len(av));
	//will need to free this memory - but when?
	
	for (i = 0; i < count; i++) {
		SV** elem = av_fetch(av, i, 0);
		
		if (!elem || !*elem) {
			croak("foo");
		}
		
		ret[i] = SvPV_nolen(*elem);
	}
	
	return ret;
}

SV* CharArray2Aref(char** var, int count) {
	AV* av = newAV();
	int i;
	
	for (i = 0; i < count; i++) {
		av_store(av, i, newSVpv(var[i], 0));
	}
	
	return newRV_noinc((SV*) av);
}

UTIL
	
	close $fh;
}

1;
