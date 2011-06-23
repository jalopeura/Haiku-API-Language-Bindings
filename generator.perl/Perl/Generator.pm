package Perl::Generator;
use File::Spec;
use File::Path;
use Perl::Module;
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
	for my $bundle ($bindings->bundles) {
		for my $bundled_bindings ($bundle->bindings_collection) {
			$self->generate(
				bindings => $bundled_bindings,
				target => $target,
			);
			my @q = split /::/, $bundled_bindings->name;
			push @bundledirs, $q[-1];
		}
	}
	
	# create and generate the module (main package)
	# (it will create any additional packages)
	my $module = new Perl::Module($bindings);
	$module->generate($target, $lib_folder, $class_folder);
	
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
	for my $links ($bindings->links_collection) {
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

# allow keyword-style entry (eventually)
# alter ParamParser into Params (???)

