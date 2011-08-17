use Common::BaseObject;

package Properties;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	property => {
		key => 'properties',
		class => 'Property+',
	},
);

sub _children { %children }

package Property;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(
	name type string-length array-length
	max-string-length
	pass-as-pointer
);	# max-array-length?
my @required_data = qw(name type);
my @bool_attrs = qw(pass-as-pointer);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _required_data { @required_data }
sub _bool_attrs { @bool_attrs }

1;
