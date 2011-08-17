use Common::BaseObject;

package Types;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	type => {
		key => 'types',
		class => 'Type+',
	},
);

sub _children { %children }

package Type;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name builtin target string-length max-string-length);	# array-length and max-array-length?
my @required_data = qw(name builtin);

sub _attributes { @attributes }
sub _required_data {
	my ($self) = @_;
	
	my $b = $self->builtin;
	if ($b eq 'object' or $b eq 'object_ptr'
		or $b eq 'responder' or $b eq 'responder_ptr') {
		return (@required_data, 'target');
	}
	return @required_data;
}

1;
