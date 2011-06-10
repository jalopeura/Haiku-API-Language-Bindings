use File::Spec;
use Common::Bindings;
use strict;

my %generators = (
	perl => 'Perl::Generator',
);

my ($target, @langs, @files);

while (@ARGV) {
	my $arg = shift @ARGV;
	
	if ($arg eq '-t') {
		$target = shift @ARGV;
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
	eval qq(use $generators{$l}; push \@generators, [ new $generators{$l}, '$t' ];) or die $@;
}

for my $file (@files) {
	print "Generating bindings for $file...\n";
	unless (-e $file) {
		die "File '$file' not found\n";
	}
	my $bindings = new Bindings(
		source => $file,
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
	my $sl = join("\t\n", sort keys %generators);
	
	die <<USAGE;
Usage:

generator.pl -t TARGET -l LANG FILES
TARGET is the folder you want the generated files to end up
LANG is the language(s) to generated bindings for (one or more)
FILES is a whitespace-separated list if binding definition files

Supported languages are
	$sl

Example:
generate.pl -d generated -t perl -t python binding.def
USAGE
}
