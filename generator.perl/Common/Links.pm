package Link;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	# link element can have the following attributes:
	# lib
	for my $attr (qw(lib)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# link element can have the following child elements:
	# N/A
	for my $child (@{ $element->children }) {
		# link has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		die "Unsupported child of link element: $cn";
	}
	
	return $self;
}

sub lib {
	my ($self) = @_;
	return $self->{lib};
}

package Links;
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
	
	# links element can have the following child elements:
	# link
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# links has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'link') {
				push @{ $self->{children} }, new Link($child);
				next;
			}
			
			die "Unsupported child of links element: $cn";
		}
	}
}

sub links {
	my ($self) = @_;
	return @{ $self->{children} };
}

1;
