package Python::Generator;
use File::Spec;
use File::Path;
use File::Copy;
use Python::Package;
use strict;

my $ext_folder = 'ext';

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
	
	# create this now so we can pass it in
	my $package = new Python::Package($bindings, $options{parent});
	
	# if the binding has any bundles, generate them
	my (@bundledirs, @packages);
	if ($bindings->has('bundle')) {
		for my $bundled_bindings ($bindings->bundle->bindings) {
			my $pkg = $self->generate(
				bindings => $bundled_bindings,
				target => $target,
				parent => $package,
			);
			my @q = split /::/, $bundled_bindings->name;
			push @bundledirs, $q[-1];
			push @packages, $pkg;
		}
	}
	
	# generate the package
	$package->generate($target, $ext_folder);
	
	# are we a real package or just a bundle?
	if ($package->has('classes') or $package->has('constants')) {
		unshift @packages, $package
	}
	
	my %libs;
	if ($package->has('link') and $package->link->has('libs')) {
		for my $lib ($package->link->libs) {
			$libs{ $lib->name }++;
		}
	}
	my $libs = join(', ', map { qq("$_") } sort keys %libs);
	
	# determine packages (including bundled packages)
	my (%packages, @extensions);
	for my $pkg (@packages) {
		my $pkgname = $pkg->name;
		my $filename = $pkg->resolve_filename($package);
		push @extensions, <<EXT;
		Extension(
			'$pkgname',
			['$filename.cc'],
#			extra_compile_args=["-Wno-multichar"]
# I don't like doing this, because the uninitialized warning is often useful,
# but I get too many false positives if I don't
			extra_compile_args=["-Wno-multichar", "-Wno-uninitialized"],
			runtime_library_dirs=[$libs]
			)
EXT
		$packages{$pkgname} = 1;
	}
	
	my @pkgnames = keys %packages;
	my @pypackages;
	while (@pkgnames) {
		my $pkgname = shift @pkgnames;
		my @p = split /\./, $pkgname;
		for my $i (0..$#p) {
			my $chk = join('.', @p[0..$i]);
			next if $packages{$chk};
			
			$packages{$chk} = 1;
			push @pypackages, qq('$chk');
			my $pkgdir = File::Spec->catdir($target, split /\./, $chk);
			mkpath($pkgdir);
			
			my $pkginit = File::Spec->catfile($pkgdir, '__init__.py');
			open INIT, ">$pkginit" or die "Unable to create init file: $1";
			close INIT;
		}
	}

	my $setup_py_file = File::Spec->catfile($target, 'setup.py');
	my $pypackages = join(', ', @pypackages);
	my $extensions = join(",", @extensions);
	my ($name) = $bindings->{name}=~/([^:]+$)/g;
	open SETUP, ">$setup_py_file" or die "Unable to create file '$setup_py_file': $!";
	print SETUP <<DIST;
import os
# don't hard link! some systems attempt to hard link and fail
# (AFS, cygwin, maybe others)
del os.link
from distutils.core import setup, Extension
setup(name='$name',
	version='$bindings->{version}',
	packages=[$pypackages],
	ext_modules=[
$extensions
		],
	)
DIST
	close SETUP;
	
#	my $init = File::Spec->catfile($target, '__init__.py');
#	open INIT, ">$init" or die "Unable to create init file in folder '$target': $!";
#	close INIT;
	
	my $manifest_in_file = File::Spec->catfile($target, 'MANIFEST.in');
	open MANIFEST, ">$manifest_in_file" or die "Unable to create file '$manifest_in_file': $!";
	print MANIFEST <<RULE;
global-include *.py *.cc *.h *.cpp
RULE
	close MANIFEST;
	
	my $test_source_dir = '../test/python';
	my $test_target_dir = File::Spec->catdir($target, 'test');
	mkpath($test_target_dir);
	opendir DIR, $test_source_dir or die $!;
	while (my $e = readdir DIR) {
		my $file = File::Spec->catfile($test_source_dir, $e);
		next if -d $file;
		copy($file, $test_target_dir);
	}
	closedir DIR;

	return $package;
}

1;

