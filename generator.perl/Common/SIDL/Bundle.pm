use Common::Bundle;
use Common::SIDL::BaseObject;

package SIDL::Bundle;
use strict;
our @ISA = qw(Bundle SIDL::BaseObject);

sub _folder {
	my ($self) = @_;
	return $self->{_parent}->{_folder};
}

package SIDL::BundledBindings;
use Common::SIDL::Bindings;
use strict;
our @ISA = qw(SIDL::Bindings);

sub new {
	my ($class, $parent, $element) = @_;
	
#print <<INFO;
#Creating bundle from $element->{attrs}{file}
#INFO
	
	my $source = File::Spec->catfile($parent->_folder, $element->attr('name'));
	
	my $self = $class->SUPER::new(
		source => $source,
	);
	
	return $self;
}

1;
