package Constant;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	# constant element can have the following attributes:
	# name
	for my $attr (qw(name)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# constant element can have the following child elements:
	# N/A
	for my $child (@{ $element->children }) {
		# constant has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		die "Unsupported child of param element: $cn";
	}
	
	return $self;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

package Constants;
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
	
	# constants element can have the following child elements:
	# constant
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# constants has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'constant') {
				push @{ $self->{children} }, new Constant($child);
				next;
			}
			
			die "Unsupported child of links element: $cn";
		}
	}
}

sub constants {
	my ($self) = @_;
	return @{ $self->{children} };
}

1;
