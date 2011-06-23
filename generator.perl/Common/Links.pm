package Links;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	link => {
		key => 'links',
		class => 'Link',
	},
);

package Link;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(lib);
our %allowed_children = ();

1;
