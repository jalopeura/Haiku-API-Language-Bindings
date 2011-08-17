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
	
	my $source = File::Spec->catfile($parent->_folder, $element->attr('name'));
	
	my $bindings = $parent;
	until ($bindings->isa('Bindings')) {
		$bindings = $bindings->{_parent};
	}
	
	my $self = $class->SUPER::new(
		source => $source,
		imports_as_bundles => $bindings->{_imports_as_bundles},
	);
	
	return $self;
}

1;
