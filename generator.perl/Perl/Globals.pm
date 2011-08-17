use Common::Globals;
use Perl::BaseObject;

package Perl::Globals;
use strict;
our @ISA = qw(Globals Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('globals')) {
		for my $g ($self->globals) {
			$g->generate;
		}
	}
}

package Perl::Global;
use strict;
our @ISA = qw(Global Perl::Constant);

#
# implemented same way as constants, so was changed
# to inherit from Perl::Constants
#

1;
