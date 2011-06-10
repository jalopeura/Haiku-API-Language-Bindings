package Type;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	# type element can have the following attributes:
	# name builtin target
	for my $attr (qw(name builtin target)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# type element can have the following child elements:
	# N/A
	for my $child (@{ $element->children }) {
		# type has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		die "Unsupported child of type element: $cn";
	}
	
	return $self;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub builtin {
	my ($self) = @_;
	return $self->{builtin};
}

sub target {
	my ($self) = @_;
	return $self->{target};
}

package Types;
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
	
	# types element can have the following child elements:
	# type
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# types has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'type') {
				push @{ $self->{children} }, new Type($child);
				next;
			}
			
			die "Unsupported child of types element: $cn";
		}
	}
}

sub types {
	my ($self) = @_;
	return @{ $self->{children} };
}

1;
