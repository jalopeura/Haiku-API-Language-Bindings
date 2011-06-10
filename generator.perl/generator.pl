use Common::Bindings;
use Perl::Generator;
use strict;

my $bindings = new Bindings(
	source => '../defs.new/HaikuKits.def',
);

my $perlgen = new Perl::Generator;

$perlgen->generate(
	bindings => $bindings,
	target => '../generated.new/perl',
);
