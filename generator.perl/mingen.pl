use Common::Bindings;
use strict;

my $bindings = new Bindings(
	source_type => 'SIDL',
	source => '../mindefs/SIDL/HaikuKits.sidl',
#	source_type => 'TIDL',
#	source => '../mindefs/TIDL/HaikuKits.sidl',
);

use Perl::Generator;

my $perlgen = new Perl::Generator;

$perlgen->generate(
	bindings => $bindings,
	target => '../generated/perl',
);

use Python::Generator;

my $pythongen = new Python::Generator;

$pythongen->generate(
	bindings => $bindings,
	target => '../generated/python',
);
