package Perl::Package;
use File::Spec;
use File::Path;
require Perl::ParamParser;
require Perl::PMCodeGenerator;
require Perl::XSCodeGenerator;
use strict;

sub new {
	my ($class, $module, $binding, $types) = @_;
	my $self = bless {
		module  => $module,
		types   => $types,
	}, $class;
	
	$self->parse_binding($binding);
	
	return $self;
}

sub parse_binding {
	my ($self, $binding) = @_;
	
	$self->{name} = $binding->{target};
	$self->{cpp_class} = $binding->{source};
	$self->{type} = 'object_ptr';
	
	# anything to export?
	my @exports;
	for my $plain ($binding->plains) {
		push @exports, $plain->name;
	}
	for my $constant ($binding->constants) {
			push @exports, $constant->name;
	}
	
	my @isa;
	if (@exports) {
		push @isa, 'Exporter';
		$self->{exports} = \@exports;
	}
	
	# any parent classes?
	if (my $perl_isa = $binding->target_inherits) {
		for my $parent (split /\s+/, $perl_isa) {
			push @{ $self->{isa} }, $parent;
		}
	}
	
	if (@isa) {
		$self->{isa} = \@isa;
	}
	
	$self->{version} ||= $binding->{version} || $self->{module}->{version};
	
	$self->{binding} = $binding;
}

sub open_files {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	my @subpath = split /::/, $self->{name};
	my $filename = pop @subpath;

	my $xs_folder = File::Spec->catfile($folder, $xs_prefix, @subpath);
	my $pm_folder = File::Spec->catfile($folder, $pm_prefix, @subpath);
	
	mkpath($xs_folder);
	mkpath($pm_folder);
	
	# PM file
	my $pm_filename = File::Spec->catfile($pm_folder, "$filename.pm");
	open $self->{pmh}, ">$pm_filename" or die "Unable to create file '$pm_filename': $!";
	
	# XS file
	my $xs_filename = File::Spec->catfile($xs_folder, "$filename.xs");
	open $self->{xsh}, ">$xs_filename" or die "Unable to create file '$xs_filename': $!";
	
	$self->{xs_include} = File::Spec->catfile($xs_prefix, @subpath, "$filename.xs");
	
	$self->{filename} = $filename;
}

sub close_files {
	my ($self) = @_;
	close $self->{pmh};
	close $self->{xsh};
}

sub generate {
	my ($self, $folder, $pm_prefix, $xs_prefix) = @_;
	
	# if we're just a bundle, we may not have any files to generate
	return unless ($self->{binding});
	
	$self->open_files($folder, $pm_prefix, $xs_prefix);
	
	$self->generate_preamble;
	
	$self->generate_functions;
	
	$self->generate_postamble;
	
	$self->close_files;
}

sub generate_preamble {
	my ($self) = @_;
	
	$self->generate_pm_preamble;
	$self->generate_xs_preamble;
}

sub generate_postamble {
	my ($self) = @_;
	
	$self->generate_pm_postamble;
	$self->generate_xs_postamble;
}

sub generate_functions {
	my ($self) = @_;
	my $binding = $self->{binding};
	
	#
	# functions
	# (constructor, destructor, object methods, object event methods,
	#    class methods, plain functions)
	#
	
	my @functions;
	
	if ($binding->constructors) {
		push @functions, $binding->constructors;
	}
	if ($binding->destructor) {
		push @functions, $binding->destructor;
	}
	if ($binding->methods) {
		push @functions, $binding->methods;
	}
	if ($binding->events) {
		push @functions, $binding->events;
	}
	if ($binding->statics) {
		push @functions, $binding->statics;
	}
	if ($binding->plains) {
		push @functions, $binding->plains;
	}
	
	for my $function (@functions) {
		my $params = $self->parse_params($function);
		$self->generate_xs_function($function, $params);
	}
	
	#
	# properties
	#
	
	for my $property ($binding->properties) {
		$self->generate_xs_property($property);
	}
	
	#
	# constants
	#
	
	for my $constant ($binding->constants) {
		$self->generate_xs_constant($constant);
	}
}

1;
