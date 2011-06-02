package Perl::Generator;
use strict;

sub write_utility_h_file {
	my ($self) = @_;
	
	my $filename = "$self->{folder}/$self->{package}Utils.h";
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	# write an intro comment
	print OUT <<INTRO;
/*
 * Automatically generated file for creating Perl bindings for the Haiku API
 */

#include "$self->{master_include}"

SV* create_perl_object(IV cpp_obj_address, const char* perl_class_name, bool must_not_delete = false);HV* get_hidden_hash(SV* perl_obj);
HV* get_hidden_hash(SV* perl_obj);
void delete_perl_object(SV* perl_obj);
void update_must_not_delete(SV* perl_obj, bool must_not_delete);
IV extract_cpp_object(SV* perl_obj);
bool can_delete_cpp_object(SV* perl_obj);

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
				print OUT <<PROPERTY;
// ${class_name}::${prop_name}
I32 get_${class_name}_${prop_name}(IV index, SV* magic_$prop_name);
I32 set_${class_name}_${prop_name}(IV index, SV* magic_$prop_name);
SV* create_${class_name}_${prop_name}($class_name* obj);

PROPERTY
			}
		}
	}
	
	close OUT;
}

1;
