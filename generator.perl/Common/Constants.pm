package Constants;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	constant => {
		key => 'constants',
		class => 'Constant',
	},
);

package Constant;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(name group);
our %allowed_children = (
	doc => {
		key => 'doc',
		class => 'Doc',
	},
);

1;
