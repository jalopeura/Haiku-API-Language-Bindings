use Common::Link;
use Common::SIDL::BaseObject;

package SIDL::Link;
use strict;
our @ISA = qw(Link SIDL::BaseObject);

package SIDL::Lib;
use Common::SIDL::BaseObject;
use strict;
our @ISA = qw(Lib SIDL::BaseObject);

1;
