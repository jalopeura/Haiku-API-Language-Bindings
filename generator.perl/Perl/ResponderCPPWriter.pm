package Perl::ClassGenerator;
use strict;

sub write_responder_cpp_file {
	my ($self, $def) = @_;
	
	# determine file name and open file
	(my $filename = $def->{target})=~s!::!_!g;
	$filename = "$self->{folder}/$filename.cpp";
	$self->verify_path_for_file($filename);
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	my $class_name = $def->{cpp};
	
	my $master_include = $self->{def}{generator}{master_include};
	
	# write an intro comment
	print OUT <<INTRO;
/*
Automatically generated file for creating Perl bindings for the Haiku API
*/

#include "$master_include"

INTRO
	
	# write the CPP code
	for my $constructor (@{ $self->{constructors} }) {
		$self->write_responder_cpp_constructor(\*OUT, $constructor, $class_name, $def->{'cpp-inherit'});
	}
	
	if ($self->{destructor}) {
		$self->write_responder_cpp_destructor(\*OUT, $class_name);
	}
	
	# responder classes inherit the methods, so no need to define them here
	
	for my $event (@{ $self->{events} }) {
		$self->write_responder_cpp_event(\*OUT, $event, $class_name);
	}
	
	close OUT;
	
	$self->{responder_cpp_filename} = $filename;
}

sub write_responder_cpp_constructor {
	my ($self, $fh, $constructor, $class_name, $parent_class_name) = @_;
	
	my $cpp_params = $constructor->{params}->cpp_params;
	my $parent_params = $constructor->{params}->cpp_inputs;
	print $fh <<CONSTRUCTOR;
${class_name}::$class_name($cpp_params)
	: $parent_class_name($parent_params) {}

CONSTRUCTOR
}

sub write_responder_cpp_destructor {
	my ($self, $fh, $class_name) = @_;
	
	print $fh <<DESTRUCTOR;
${class_name}::~$class_name() {}

DESTRUCTOR
}

sub write_responder_cpp_event {
	my ($self, $fh, $event, $class_name) = @_;
	
	my $cpp_params = $event->{params}->cpp_params;
	my $perl_event_params = $event->{params}->perl_event_params;
	my $perl_event_param_count = $event->{params}->perl_event_param_count;
		$perl_event_param_count++;	# for the perl object
	my $perl_event_param_defs = $event->{params}->perl_event_param_defs;
	
	print $fh <<EVENT;
$event->{retval}{type} ${class_name}::$event->{def}{cpp}($cpp_params) {
$perl_event_param_defs
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
	
	EXTEND(SP, $perl_event_param_count);
	PUSHMARK(SP);
	PUSHs(this->perl_obj);
	
$perl_event_params
	
	PUTBACK;
	call_method("$event->{def}{target}", G_DISCARD);
} // ${class_name}::$event->{def}{cpp}
EVENT
}

1;

__END__

		
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
