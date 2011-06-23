package Params;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	param => {
		key => 'params',
		class => 'Param',
	},
);

package Param;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(name type deref action default success must-not-delete);
our %allowed_children = (
	doc => {
		key => 'docs',
		class => 'Doc',
	},
);


package Return;
use strict;
our @ISA = qw(BaseObject);

our $want_content = 0;
our @allowed_attrs = qw(name type action must-not-delete);
our %allowed_children = ();

1;
