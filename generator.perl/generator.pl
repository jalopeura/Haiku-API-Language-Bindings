use Common::Bindings;
use strict;

my $perl = 1;
my $python = 1;

if ($perl) {	# or other languages using separate modular extensions
	print "Separate modular extensions...\n";
	
	my $modular_bindings = new Bindings(
#		imports_as_bundles => 1,
		source_type => 'SIDL',
		source => '../defs/SIDL/HaikuKits.sidl',
	#	source_type => 'TIDL',
	#	source => '../mindefs/TIDL/HaikuKits.sidl',
	);
	
	if ($perl) {
		eval "use Perl::Generator";
		die if $@;
		
		my $perlgen = new Perl::Generator;
		
		$perlgen->generate(
			bindings => $modular_bindings,
			target => '../generated/perl',
		);
	}
}

if ($python) {	# or other languages using a single global extension
	print "Single global extension...\n";
	
	my $global_bindings = new Bindings(
		source_type => 'SIDL',
		source => '../defs/SIDL/Haiku.sidl',
	#	source_type => 'TIDL',
	#	source => '../mindefs/TIDL/Haiku.sidl',
	);
	
	if ($python) {
		eval "use Python::Generator";
		die if $@;
		
		my $pythongen = new Python::Generator;
		
		$pythongen->generate(
			bindings => $global_bindings,
			target => '../generated/python',
		);
	}
}
