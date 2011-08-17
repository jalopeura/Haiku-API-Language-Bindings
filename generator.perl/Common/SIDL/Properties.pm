use Common::Properties;
use Common::SIDL::BaseObject;

package SIDL::Properties;
use strict;
our @ISA = qw(Properties SIDL::BaseObject);

package SIDL::Property;
use strict;
our @ISA = qw(Property SIDL::BaseObject);

1;
