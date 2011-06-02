#
# The generator is currently a Perl script; at some point it should be
# replaced with a C++ version, but for now the focus is on making sure
# this approach works and making some working bindings available.
#
use DefParser;
use Perl::Generator;
use strict;

my $parser = new DefParser;
my $perlgen = new Perl::Generator;

$parser->generators($perlgen);

$parser->parse('../defs/ApplicationKit/ApplicationKit.def', '../generated');
$parser->parse('../defs/InterfaceKit/InterfaceKit.def', '../generated');
