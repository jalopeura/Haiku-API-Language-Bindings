package Python::Generator;
use File::Spec;
use File::Path;
use File::Copy;
use Python::Package;
use strict;

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
	
#	File::Path->remove_tree($target);
	
	# drop build from last time
	for my $drop (qw(build dist test)) {
		my $dropdir = File::Spec->catdir($target, $drop);
		if (-e $dropdir) {
			File::Path->remove_tree($dropdir);;
		}
	}
	
	# create the package
	my $package = new Python::Package($bindings, $options{parent});
	my @packages = ($package);	
	
	# if the binding has any bundles, generate them and save their info
	my @bundledirs;
	for my $bundle ($bindings->bundles) {
		for my $bundled_bindings ($bundle->bindings_collection) {
			push @packages, $self->generate(
				bindings => $bundled_bindings,
				target => $target,
				parent => $package,
			);
			my @q = split /::/, $bundled_bindings->name;
			push @bundledirs, $q[-1];
		}
	}
	
	# generate the package
	# (it will create any additional packages)
	$package->generate($target);
	
	# now I do myself (unless I'm just a bundle)
	# and any bundled modules
	my (%extensions, @extensions);
	for my $pkg (@packages) {
		next unless $pkg->{name};
		my $filename = $pkg->resolve_filename($package);
		$extensions{ $pkg->{name} } = 'c++';
		push @extensions, qq(Extension('$pkg->{name}', ['$filename.cc']));
#print $pkg->{name},"\n";
#print join(':::', $pkg, %$pkg),"\n";
	}
	
	# for packages named X.Y, verify X exists
	# if not, add an empty __init__.py
	my @pymodules;
	for my $pkg (keys %extensions) {
		my @pkg = split /\./, $pkg;
		pop @pkg;
		for my $i (0..$#pkg) {
			my $chk = join('.', @pkg[0..$i]);
			next if $extensions{$chk};
			
			my $dir = File::Spec->catdir($target, @pkg[0..$i]);
			mkpath($dir);
			my $init = File::Spec->catfile($dir, '__init__.py');
			open INIT, ">$init" or die "Unable to create init file in folder '$dir': $!";
			close INIT;
			
			$extensions{$chk} = 'py';
			push @pymodules, qq('$chk');
		}
	}

	# any empty folders in the path need to have empty __init__.py
	# files in them so python knows they contain modules
	my @pypackages;
	my @folders = ('.');
	while (@folders) {
		my $f = shift @folders;
		my @f = File::Spec->splitdir($f);
		if (@f) {
#print "$f[-1] from $f\n";
			my $chk = File::Spec->catfile($target, $f, "$f[-1].cc");
			unless (-e $chk) {
				my $init = File::Spec->catfile($target, $f, '__init__.py');
				open INIT, ">$init" or die "Unable to create init file in folder '$f': $!";
				close INIT;
				my $m = join('.', @f);
				unless ($m eq '.') {
					push @pypackages, qq('$m');
				}
			}
		}
		
		my $dir = File::Spec->catdir($target, $f);
		opendir DIR, $dir or die "Unable to read folder '$dir': $!";
		my @e = readdir DIR;
		closedir DIR;
		
		for my $e (sort @e) {
			next if ($e eq '.' or $e eq '..');
			my $d = File::Spec->catdir($target, $f, $e);
			next unless -d $d;
			push @folders, File::Spec->catdir($f, $e);
		}
	}

	my $setup_py_file = File::Spec->catfile($target, 'setup.py');
	my $pypackages = join(', ', @pypackages);
	my $extensions = join(",\n\t\t", @extensions);
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

__END__

# CODE
# not sure Py_BuildValue("") is okay; may need to be Py_BuildValue(NULL)
# may need to alter setup.py for bundles - look into this
#
# TEST
# make sure everything compiles properly
# read a python tutorial
# write a test program
# debug
