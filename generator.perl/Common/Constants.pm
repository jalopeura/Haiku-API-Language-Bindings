use Common::BaseObject;

package Constants;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	constant => {
		key => 'constants',
		class => 'Constant+',
	},
);

sub _children { %children }

package Constant;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name group);
my @required_data = qw(name);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _required_data { @required_data }

1;
