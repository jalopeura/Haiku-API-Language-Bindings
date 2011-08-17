use Common::Include;
use Perl::BaseObject;

package Perl::Include;
use strict;
our @ISA = qw(Include Perl::BaseObject);

package Perl::File;
use strict;
our @ISA = qw(File Perl::BaseObject);

1;
