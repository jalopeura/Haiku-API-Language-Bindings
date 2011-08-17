use Common::BaseObject;

package Link;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	lib => {
		key => 'libs',
		class => 'Lib+',
	},
);

sub _children { %children }

package Lib;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name);
my @required_data = qw(name);

sub _attributes { @attributes }
sub _required_data { @required_data }

1;
