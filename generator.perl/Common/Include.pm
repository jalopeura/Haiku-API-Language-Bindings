use Common::BaseObject;

package Include;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	file => {
		key => 'files',
		class => 'File+',
	},
);

sub _children { %children }

package File;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name);
my @required_data = qw(name);

sub _attributes { @attributes }
sub _required_data { @required_data }

1;
