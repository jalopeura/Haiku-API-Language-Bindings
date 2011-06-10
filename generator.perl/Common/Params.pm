package Param;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		element => $element,
	}, $class;
	
	# param element can have the following attributes:
	# name, type, deref, action, default, success, must-not-delete
	for my $attr (qw(name type deref action default success must-not-delete)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# param element can have the following child elements:
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

package Return;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		children => [],
	}, $class;
	
	# return element can have the following attributes:
	# name, type, action
	for my $attr (qw(name type)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# return element can have the following child elements:
	# N/A
	for my $child (@{ $element->children }) {
		# bundles has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		die "Unsupported child of link element: $cn";
	}
	
	return $self;
}

package Params;
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
	
	# params element can have the following child elements:
	# param
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# params has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'param') {
				push @{ $self->{children} }, new Param($child);
				next;
			}
			
			die "Unsupported child of links element: $cn";
		}
	}
}

sub params {
	my ($self) = @_;
	return @{ $self->{children} };
}

1;
