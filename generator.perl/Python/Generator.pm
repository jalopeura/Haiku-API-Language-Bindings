package Python::Generator;
use File::Spec;
use File::Path;
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
	my @extensions;
	for my $pkg (@packages) {
		next unless $pkg->{name};
		my $filename = $pkg->resolve_filename($package);
		push @extensions, qq(Extension('$pkg->{name}', ['$filename.cc']));
#print $pkg->{name},"\n";
#print join(':::', $pkg, %$pkg),"\n";
	}
	
	my $setup_py_file = File::Spec->catfile($target, 'setup.py');
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
	ext_modules=[
		$extensions
		],
	)
DIST
	close SETUP;
	
	my $manifest_in_file = File::Spec->catfile($target, 'MANIFEST.in');
	open MANIFEST, ">$manifest_in_file" or die "Unable to create file '$manifest_in_file': $!";
	print MANIFEST <<RULE;
global-include *.py *.cc *.h *.cpp
RULE
	close MANIFEST;
	
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
