package Includes;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	include => {
		key => 'includes',
		class => 'Include',
	},
);

package Include;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(file);
our %allowed_children = ();

1;
