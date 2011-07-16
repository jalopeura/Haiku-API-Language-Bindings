use Common::Bindings;
use strict;

my $perl = 1;
my $python = 0;

my ($modular_bindings, $global_bindings);

if ($perl) {	# or any future languages using modular extensions
	print "Separate modular extensions...\n";

	$modular_bindings = new Bindings(
		source_type => 'SIDL',
		source => '../mindefs/SIDL/HaikuKits.sidl',
#		source_type => 'TIDL',
#		source => '../mindefs/TIDL/HaikuKits.sidl',
	);
}

if ($perl) {
	eval "use Perl::Generator";

	my $perlgen = new Perl::Generator;

	$perlgen->generate(
		bindings => $modular_bindings,
		target => '../generated/perl',
	);
}

if ($python) {	# or any future languages using modular extensions
	print "Single global extension...\n";

	$global_bindings = new Bindings(
		source_type => 'SIDL',
		source => '../mindefs/SIDL/Haiku.sidl',
#		source_type => 'TIDL',
#		source => '../mindefs/TIDL/Haiku.sidl',
	);
}

if ($python) {
	eval "use Python::Generator";

	my $pythongen = new Python::Generator;

	$pythongen->generate(
		bindings => $global_bindings,
		target => '../generated/python',
	);
}
