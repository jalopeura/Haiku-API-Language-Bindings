use Common::Globals;
use Common::SIDL::BaseObject;

package SIDL::Globals;
use strict;
our @ISA = qw(Globals SIDL::BaseObject);

package SIDL::Global;
use strict;
our @ISA = qw(Global SIDL::BaseObject);

1;
