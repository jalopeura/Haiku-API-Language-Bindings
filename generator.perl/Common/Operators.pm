use Common::BaseObject;

package Operators;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	operator => {
		key => 'operators',
		class => 'Operator+',
	},
);

sub _children { %children }

package Operator;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name);
my @required_data = qw(name);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _required_data { @required_data }

1;
