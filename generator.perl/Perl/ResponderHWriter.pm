package Perl::ClassGenerator;
use strict;

sub write_responder_h_file {
	my ($self, $def) = @_;
	
	# determine file name and open file
	(my $filename = $def->{target})=~s!::!_!g;
	$filename = "$self->{folder}/$filename.h";
	$self->verify_path_for_file($filename);
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	my $class_name = $def->{cpp};
	
	# write an intro comment
	print OUT <<INTRO;
/*
 * Automatically generated file for creating Perl bindings for the Haiku API
 */

INTRO
	
#	# do includes
#	my $generator = $self->{def}{generator};
#	print OUT qq(#include "perl.h"\n);
#	if ($generator->{include}) {
#		for my $file (@{ $generator->{include} }) {
#			print OUT qq(#include <$file>\n);
#		}
#		print OUT "\n";
#	}

	# start class
	print OUT <<CLASS;
class $class_name : public $def->{'cpp-inherit'} {
	public:
CLASS
	
	# write the XS code
	for my $constructor (@{ $self->{constructors} }) {
		$self->write_responder_h_constructor(\*OUT, $constructor, $class_name);
	}
	
	if ($self->{destructor}) {
		$self->write_responder_h_destructor(\*OUT, $class_name);
	}
	
	# responder classes inherit the methods, so no need to define them here
	
	for my $event (@{ $self->{events} }) {
		$self->write_responder_h_event(\*OUT, $event, $class_name);
	}
	
	print OUT <<END;
		SV* perl_obj;
}; // $class_name
END
	
	close OUT;
	
	$self->{responder_h_filename} = $filename;
}

sub write_responder_h_constructor {
	my ($self, $fh, $constructor, $class_name) = @_;
	
	my $h_params = $constructor->{params}->h_params;
	print $fh <<CONSTRUCTOR;
		$class_name($h_params);
CONSTRUCTOR
}

sub write_responder_h_destructor {
	my ($self, $fh, $class_name) = @_;
	
	print $fh <<DESTRUCTOR;
		~$class_name();
DESTRUCTOR
}

sub write_responder_h_event {
	my ($self, $fh, $event, $class_name) = @_;
	
	my $h_params = $event->{params}->h_params;
	print $fh <<EVENT;
		$event->{retval}{type} $event->{def}{cpp}($h_params);
EVENT
}

1;
