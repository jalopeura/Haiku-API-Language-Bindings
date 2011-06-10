package Property;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	# property element can have the following attributes:
	# name type
	for my $attr (qw(name type)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# property element can have the following child elements:
	# N/A
	for my $child (@{ $element->children }) {
		# bundles has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		die "Unsupported child of param element: $cn";
	}
	
	return $self;
}

package Properties;
use strict;

sub new {
	my ($class, @elements) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	$self->add(@elements);
	
	return $self;
}

sub add {
	my ($self, @elements) = @_;
	
	# properties element can have the following child elements:
	# property
	for my $element (@elements) {
	for my $child (@{ $element->children }) {
		# properties has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		if ($cn eq 'property') {
			push @{ $self->{children} }, new Property($child);
			next;
		}
		
		die "Unsupported child of links element: $cn";
	}
	}
}

sub properties {
	my ($self) = @_;
	return @{ $self->{children} };
}

1;
