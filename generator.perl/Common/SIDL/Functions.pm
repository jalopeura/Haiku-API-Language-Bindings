use Common::Functions;
use Common::SIDL::BaseObject;

package SIDL::Functions;
use strict;
our @ISA = qw(Functions SIDL::BaseObject);

package SIDL::Constructor;
use strict;
our @ISA = qw(Constructor SIDL::BaseObject);

package SIDL::Destructor;
use strict;
our @ISA = qw(Destructor SIDL::BaseObject);

package SIDL::Method;
use strict;
our @ISA = qw(Method SIDL::BaseObject);

package SIDL::Event;
use strict;
our @ISA = qw(Event SIDL::BaseObject);

package SIDL::Static;
use strict;
our @ISA = qw(Static SIDL::BaseObject);

package SIDL::Plain;
use strict;
our @ISA = qw(Plain SIDL::BaseObject);

package SIDL::Param;
use strict;
our @ISA = qw(Param SIDL::BaseObject);

package SIDL::Return;
use strict;
our @ISA = qw(Return SIDL::BaseObject);

1;
