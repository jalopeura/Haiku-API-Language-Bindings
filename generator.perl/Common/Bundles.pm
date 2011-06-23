package Bundle;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw();
our %allowed_children = (
	bindings => {
		key => 'bindings_collection',
		class => 'BundledBindings',
	},
);

package BundledBindings;
use strict;
our @ISA = qw(Bindings);

our ($content_as, @allowed_attrs, %allowed_children, %child_handlers);

*content_as = \$Bindings::content_as;
*allowed_attrs = \@Bindings::allowed_attrs;
*allowed_children = \%Bindings::allowed_children;
*child_handlers = \%Bindings::child_handlers;

sub new {
	my ($class, $parent, $element) = @_;
	
#print <<INFO;
#Creating bundle from $element->{attrs}{file}
#INFO
	
	my $source = File::Spec->catfile($parent->_folder, $element->attr('file'));
	
	my $self = $class->SUPER::new(
		source => $source,
	);
	
	return $self;
}

1;
