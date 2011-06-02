package Perl::ClassGenerator;
use Perl::Params;
use Perl::BasicXSWriter;
use Perl::BasicPMWriter;
use Perl::ResponderHWriter;
use Perl::ResponderCPPWriter;
use Perl::ResponderXSWriter;
use Perl::ResponderPMWriter;
use strict;

sub new {
	my ($class, $folder, $def) = @_;
	my $self = bless {
		folder => $folder,
		def   => $def,
		name  => $def->{target},
	}, $class;
	return $self;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub write {
	my ($self) = @_;
	
	my (@map, @responders);
	$self->{class_map} = \@map;
	$self->{responder_classes} = \@responders;
	
	$self->write_basic_xs_file;
	$self->write_basic_pm_file;
	push @map, [ $self->{def}{cpp}, $self->{def}{target}, undef ];
	
	if ($self->{events}) {
		my $rdef = {
			'cpp-inherit'    => $self->{def}{cpp},
			cpp              => 'Custom_' . $self->{def}{cpp},
			'target-inherit' => $self->{def}{target},
		};
		my @t = split /::/, $self->{def}{target};
		$t[-1] = 'Custom' . $t[-1];
		$rdef->{target} = join('::', @t);
		
		$self->write_responder_h_file($rdef);
		$self->write_responder_cpp_file($rdef);
		$self->write_responder_xs_file($rdef);
		$self->write_responder_pm_file($rdef);
		
		push @map, [ $rdef->{cpp}, $rdef->{target}, $self->{def}{target} ];
	}
	
	# if we have events, clone self and alter class name to be a responder
	#   then write XS, H, and CPP files
}

sub class_map {
	my ($self) = @_;
	return @{ $self->{class_map} } if $self->{class_map};
	return;
}

sub responder_classes {
	my ($self) = @_;
	return @{ $self->{responder_classes} };
}

sub verify_path_for_file {
	my ($self, $file) = @_;
	my @path = split m:/:, $file;
	pop @path;	# take off filename portion
	for my $i (0..$#path) {
		my $p = join('/', @path[0..$i]);
		next if -e $p;
		mkdir $p;
	}
}

sub include {
	my ($self, @files) = @_;
	NEW: for my $new (@files) {
		for my $existing (@{ $self->{include} }) {
			next NEW if $new eq $existing;
		}
		push @{ $self->{include} }, $new;
	}
}

sub import {
	my ($self, @classes) = @_;
	NEW: for my $new (@classes) {
		for my $existing (@{ $self->{import} }) {
			next NEW if $new eq $existing;
		}
		push @{ $self->{import} }, $new;
	}
}

sub module {
	my ($self, $module) = @_;
	$self->{module} ||= $module;
}

sub constructor {
	my ($self, $def, @params) = @_;
	
	my $params = new Perl::Params(@params);
	$self->{constructors} ||= [];
	push @{ $self->{constructors} }, {
		def => $def,
		params => $params,
	};
}

sub destructor {
	my ($self) = @_;
	
	$self->{destructor} = {};
}

sub method {
	my ($self, $def, $return, @params) = @_;
	
	my $params = new Perl::Params(@params);
	$params->parse($return, 1);
	$self->{methods} ||= [];
	push @{ $self->{methods} }, {
		def => $def,
		params => $params,
		retval => $return,
	};
}

sub event {
	my ($self, $def, $return, @params) = @_;
	
	my $params = new Perl::Params(@params);
	$params->parse($return, 1);
	$self->{events} ||= [];
	push @{ $self->{events} }, {
		def => $def,
		params => $params,
		retval => $return,
	};
}

sub property {
	my ($self, $property) = @_;
	$self->{properties} ||= [];
	push @{ $self->{properties} }, $property;
}

sub constant {
	my ($self, $constant) = @_;
	$self->{constants} ||= [];
	push @{ $self->{constants} }, $constant;
}

sub version {
	my ($self) = @_;
	return $self->{def}{version} || '0.01';	# default
}

1;
__END__

