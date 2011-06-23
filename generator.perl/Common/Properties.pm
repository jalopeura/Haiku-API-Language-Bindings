package Properties;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	property => {
		key => 'properties',
		class => 'Property',
	},
);

package Property;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(name type);
our %allowed_children = (
	doc => {
		key => 'docs',
		class => 'Doc',
	},
);

1;
