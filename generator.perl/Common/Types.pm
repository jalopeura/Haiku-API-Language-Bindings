package Types;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	type => {
		key => 'types',
		class => 'Type',
	},
);

package Type;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(name builtin target);
our %allowed_children = ();

1;
