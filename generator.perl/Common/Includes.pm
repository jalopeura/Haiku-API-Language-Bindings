package Include;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	# include element can have the following attributes:
	# file
	for my $attr (qw(file)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# include element can have the following child elements:
	# N/A
	for my $child (@{ $element->children }) {
		# include has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		die "Unsupported child of include element: $cn";
	}
	
	return $self;
}

sub file {
	my ($self) = @_;
	return $self->{file};
}

package Includes;
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
	
	# includes element can have the following child elements:
	# include
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# inlcudes has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'include') {
				push @{ $self->{children} }, new Include($child);
				next;
			}
			
			die "Unsupported child of includes element: $cn";
		}
	}
}

sub includes {
	my ($self) = @_;
	return @{ $self->{children} };
}

1;
