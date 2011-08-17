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

my @attributes = qw(
	name type group string-length array-length
	max-string-length
);	# max-array-length?
my @required_data = qw(name type);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _required_data { @required_data }

1;
