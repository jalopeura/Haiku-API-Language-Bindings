package Functions;
use Common::Params;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	constructor => {
		key => 'constructors',
		class => 'Constructor',
	},
	destructor => {
		key => 'destructors',
		class => 'Destructor',
	},
	method => {
		key => 'methods',
		class => 'Method',
	},
	event => {
		key => 'events',
		class => 'Event',
	},
	static => {
		key => 'statics',
		class => 'Static',
	},
	plain => {
		key => 'plains',
		class => 'Plain',
	},
);

package Function;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(name overload-name);
our %allowed_children = (
	params => {
		key => 'params_collection',
		class => 'Params',
	},
	return => {
		key => 'returns',
		class => 'Return',
	},
	doc => {
		key => 'docs',
		class => 'Doc',
	},
);

package Constructor;
use strict;
our @ISA = qw(Function);

our ($content_as, @allowed_attrs, %allowed_children);

*content_as = \$Function::content_as;
*allowed_attrs = \@Function::allowed_attrs;
%allowed_children = %Function::allowed_children;
*allowed_children = \%Function::allowed_children;

package Destructor;
use strict;
our @ISA = qw(Function);

our ($content_as, @allowed_attrs, %allowed_children);

*content_as = \$Function::content_as;
*allowed_attrs = \@Function::allowed_attrs;
*allowed_children = \%Function::allowed_children;

package Method;
use strict;
our @ISA = qw(Function);

our ($content_as, @allowed_attrs, %allowed_children);

*content_as = \$Function::content_as;
*allowed_attrs = \@Function::allowed_attrs;
*allowed_children = \%Function::allowed_children;

package Event;
use strict;
our @ISA = qw(Function);

our ($content_as, @allowed_attrs, %allowed_children);

*content_as = \$Function::content_as;
*allowed_attrs = \@Function::allowed_attrs;
*allowed_children = \%Function::allowed_children;

package Static;
use strict;
our @ISA = qw(Function);

our ($content_as, @allowed_attrs, %allowed_children);

*content_as = \$Function::content_as;
*allowed_attrs = \@Function::allowed_attrs;
*allowed_children = \%Function::allowed_children;

package Plain;
use strict;
our @ISA = qw(Function);

our ($content_as, @allowed_attrs, %allowed_children);

*content_as = \$Function::content_as;
*allowed_attrs = \@Function::allowed_attrs;
*allowed_children = \%Function::allowed_children;

1;
