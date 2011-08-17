use Common::BaseObject;

package Functions;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	constructor => {
		key => 'constructors',
		class => 'Constructor+',
	},
	destructor => {
		key => 'destructor',
		class => 'Destructor',
	},
	method => {
		key => 'methods',
		class => 'Method+',
	},
	event => {
		key => 'events',
		class => 'Event+',
	},
	static => {
		key => 'statics',
		class => 'Static+',
	},
	plain => {
		key => 'plains',
		class => 'Plain+',
	},
);

sub _children { %children }

# convenience package for others to inherit; no 'function' in definitions
package Function;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name overload-name);
my %children = (
	param => {
		key => 'params',
		class => 'Param+',
	},
	return => {
		key => 'return',
		class => 'Return',
	},
);
my @required_data = qw(name);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _children { %children }
sub _required_data { @required_data }

package Constructor;
use strict;
our @ISA = qw(Function);

my @attributes = qw(overload-name);
my %children = (
	param => {
		key => 'params',
		class => 'Param+',
	},
);

sub _attributes { @attributes }
sub _children { %children }
sub _required_data {}

package Destructor;
use strict;
our @ISA = qw(Function);

sub _children {}
sub _attributes {}
sub _required_data {}

package Method;
use strict;
our @ISA = qw(Function);

package Event;
use strict;
our @ISA = qw(Function);

package Static;
use strict;
our @ISA = qw(Function);

package Plain;
use strict;
our @ISA = qw(Function);

package Param;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(
	name type action default success must-not-delete
	string-length array-length pass-as-pointer
	max-string-length
);	# max-array-length?
my %defaults = (
	action => 'input',
);
my @required_data = qw(name type action);
my @bool_attrs = qw(pass-as-pointer must-not-delete);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _required_data { @required_data }
sub _bool_attrs { @bool_attrs }

package Return;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(
	name type action success must-not-delete
	string-length array-length pass-as-pointer
	max-string-length
);	# max-array-length?
my %defaults = (
	action => 'output',
	name   => 'retval',
	type   => 'void',
);
my @required_data = qw(name type action);
my @bool_attrs = qw(pass-as-pointer must-not-delete);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _defaults { %defaults }
sub _required_data { @required_data }
sub _bool_attrs { @bool_attrs }

1;
