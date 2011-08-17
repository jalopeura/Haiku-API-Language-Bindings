use Common::Link;
use Python::BaseObject;

package Python::Link;
use strict;
our @ISA = qw(Link Python::BaseObject);

package Python::Lib;
use strict;
our @ISA = qw(Lib Python::BaseObject);

1;
