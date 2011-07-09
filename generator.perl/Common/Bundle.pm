use Common::BaseObject;

package Bundle;
use strict;
our @ISA = qw(BaseObject);

my %children = (
	file => {
		key => 'bindings',
		class => 'BundledBindings+',
	},
);

sub _children { %children }

package BundledBindings;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name);
my @required_data = qw(name);

sub _attributes { @attributes }
sub _required_data { @required_data }

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	
	print join("\n", %$self),"\n\n";
	
#	$self->{source_type_prefix} = 'SIDL';
}

1;
