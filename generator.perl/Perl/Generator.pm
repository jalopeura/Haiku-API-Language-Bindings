package Perl::Generator;
use File::Spec;
use File::Path;
use Perl::Types;
require Perl::ClassGenerator;
use strict;

my $class_folder = 'ext';
my $lib_folder = 'lib';

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	return $self;
}

sub generate {
	my ($self, %options) = @_;
	
	my $bindings = $options{bindings};
	my @p = split /::/, $bindings->name;
	my $folder = $p[-1];
	my $target = File::Spec->catdir($options{target} || '.', $folder);
	mkpath($target);
print "Generating $target\n";
	
	# if the binding has any bundles, generate them
	my @bundledirs;
	if (my $bundles = $bindings->bundles) {
		for my $bundle (@{ $bundles->bundles }) {
			$self->generate(
				bindings => $bundle,
				target => $target,
			);
			my @q = split /::/, $bundle->name;
			push @bundledirs, $q[-1];
		}
	}
	
	$self->{types} = new Perl::Types;
	if (my $types = $bindings->types) {
		for my $type ($types->types) {
			$self->{types}->register_type(
				$type->name,
				$type->builtin,
				$type->target,
			);
		}
	}
	
	# this repeats some of the code from the ClassGenerator,
	# but we need these types available before we generate classes
	if ($bindings->bindings) {
		for my $binding (@{ $bindings->bindings }) {
			my $cpp_class_name = $binding->source;
			my $perl_class_name = $binding->target;
			
			if ($cpp_class_name) {
				$self->{types}->register_type(
					"$cpp_class_name*",
					'object_ptr',
					$perl_class_name,
				);
			}
			
			if ($binding->events) {
				my $cpp_responder_name = 'Custom_' . $cpp_class_name;
				
				my @pc = split /::/, $perl_class_name;
				$pc[-1] = 'Custom' . $pc[-1];
				my $perl_responder_name = join('::', @pc);
				
				$self->{types}->register_type(
					"$cpp_responder_name*",
					'responder_ptr',
					$perl_responder_name,
				);
			}
		}
	}
	
	my (@xs_files, @h_files, @cpp_files);
	
	# create all our individual classes
	if ($bindings->bindings) {
		# prepare folders
		my $xs_folder = File::Spec->catdir($target, $class_folder);
		mkpath($xs_folder);
		my $pm_folder = File::Spec->catdir($target, $lib_folder);
		mkpath($pm_folder);
		
		# generate bindings
		for my $binding (@{ $bindings->bindings }) {
			my %files = $self->generate_class($bindings, $binding, $target, $class_folder, $lib_folder);
		}
	}
	
	if ($self->{types}->registered_type_count) {
		my $typemap_file = File::Spec->catfile($target, 'typemap');
		$self->{types}->write_typemap_file($typemap_file);
	}
	
	# create our makefile
		# links
	
	# Makefile.PL
	my $name = $bindings->{name};
	my $version = $bindings->{version};
	
	my @makefile_params = (
		qq('NAME'     => '$name'),
		qq('VERSION'  => '$version'),
		qq('CC'       => 'g++'),
#		qq('CCFLAGS'  => '-save-temps'),
		qq('LD'       => '\$(CC)'),
		qq('XSOPT'    => '-C++'),
#		qq('XS'       => { '$basename.xs' => '$basename.c' }),
#		qq('C'        => [$c_files]),
#		qq('H'        => [$h_files]),
#		qq('OBJECT'   => '$o_files'),
	);
	
	my @libs;
	if (my $links = $bindings->links) {
		for my $link ($links->links) {
			push @libs, $link->lib;
		}
	}
	if (@libs) {
		my $libs = join(' ', @libs);
#		push @makefile_params, qq('BSLOADLIBS' => '$libs');
		push @makefile_params, qq(dynamic_lib => { 'BSLOADLIBS' => '$libs' });
	}
	if (@bundledirs) {
		my $dirs = join(', ', map { "'$_'" } @bundledirs);
		push @makefile_params, qq('DIR'      => [ $dirs ]);
	}
	my $makefile_params = join(",\n\t", @makefile_params);
	
	my $makefile_pl = File::Spec->catfile($target, 'Makefile.PL');
	open MPL, ">$makefile_pl" or die "Unable to create Makefile.PL: $!";
	print MPL <<MAKE;
use ExtUtils::MakeMaker;

WriteMakefile(
	$makefile_params
);
MAKE
	
	# a loading test
	my $testdir = File::Spec->catdir($target, 't');
	mkpath($testdir);
	
	my $testfile = File::Spec->catdir($testdir, 'load.t');
	open TEST, ">$testfile" or die "Unable to create test: $!";
	print TEST <<OUT;
use Test::Simple tests => 1;

use $name;

ok(1);
OUT
}

1;

__END__

Verify that xsubbpp works
Verify that bundling works
Verify that everything compiles

Make timetrack merge

