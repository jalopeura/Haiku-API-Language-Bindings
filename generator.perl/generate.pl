use File::Spec;
use Common::Bindings;
use strict;

my %generators = (
	perl   => 'Perl::Generator',
	python => 'Python::Generator',
);

my ($target, $format, @langs, @files);

while (@ARGV) {
	my $arg = shift @ARGV;
	
	if ($arg eq '-t') {
		$target = shift @ARGV;
		next;
	}
	
	if ($arg eq '-f') {
		$format = shift @ARGV;
		next;
	}
	
	if ($arg eq '-l') {
		push @langs, shift @ARGV;
		next;
	}
	
	push @files, $arg;
}

unless ($target and @langs and @files) {
	usage();
}

my @generators;
for my $l (@langs) {
	unless ($generators{$l}) {
		die "Language '$l' is not supported\n";
	}
	my $t = File::Spec->catdir($target, $l);
	eval qq(use $generators{$l}; push \@generators, [ new $generators{$l}, '$t', '$format' ];) or die $@;
}

for my $file (@files) {
	print "Generating bindings for $file...\n";
	unless (-e $file) {
		die "File '$file' not found\n";
	}
	my $bindings = new Bindings(
		source      => $file,
		source_type => $format,
	);
	
	for my $generator (@generators) {
		print "\t...to $generator->[1]\n";
		$generator->[0]->generate(
			bindings => $bindings,
			target => $generator->[1],
		);
	}
}

sub usage {
	my $sl = join("\n\t", sort keys %generators);
	
	die <<USAGE;
Usage:

generator.pl -t TARGET -l LANG -f FORMAT FILES
TARGET is the folder you want the generated files to end up
LANG is the language(s) to generated bindings for (one or more)
FORMAT is the definition file format
FILES is a whitespace-separated list if binding definition files

Supported languages are
	$sl

Supported formats are
	SIDL - SGML-esque interface definition language
	TIDL - Tab-delimited interface definiton language (coming soon)

Example:
generate.pl -d generated -t perl -t python binding.def
USAGE
}
