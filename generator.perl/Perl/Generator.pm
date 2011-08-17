package Perl::Generator;
use File::Spec;
use File::Path;
use File::Copy;
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
	$bindings->check_required_data;
	my @p = split /::/, $bindings->name;
	my $folder = $p[-1];
	my $target = File::Spec->catdir($options{target} || '.', $folder);
	mkpath($target);
print "Generating $target\n";
	
	File::Path->remove_tree($target);
	
	# if the binding has any bundles, generate them
	my @bundledirs;
	if ($bindings->has('bundle')) {
		for my $bundled_bindings ($bindings->bundle->bindings) {
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
	if ($module->has('link')) {
		my $libs = join(' ', map { $_->name } $module->link->libs);
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

=pod

	my $test_target_dir = File::Spec->catdir($target, 't');
	my $test_source_dir = '../test/perl';
	mkpath($test_target_dir);
	opendir DIR, $test_source_dir or die $!;
	while (my $e = readdir DIR) {
		my $file = File::Spec->catfile($test_source_dir, $e);
		next if -d $file;
		next unless $e=~/\.t$/;
		copy($file, File::Spec->catfile($test_target_dir, $e));
	}
	closedir DIR;

=cut

	return $module;
}

1;

__END__

make sure current stuff is working again
especially make sure python is working properly
commit it

reimplement people app using the perl bindings

add lots more bindings

Interface Kit constants have ... for docs
constructors have ... for docs
params still need docs
Application::RefsReceived

May need to change some (all?) of the code to prefix converters with new mortal
 and the converters themselves to use sv_setvsv instead of =
-will compile first and see what happens

# allow exporting of constants in groups
# allow keyword-style entry (eventually)

