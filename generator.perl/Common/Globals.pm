use Common::BaseObject;

package Globals;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	global => {
		key => 'globals',
		class => 'Global+',
	},
);

sub _children { %children }

package Global;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(
	name type string-length array-length
	max-string-length
);	# max-array-length?

my @required_data = qw(name type);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _required_data { @required_data }

1;
