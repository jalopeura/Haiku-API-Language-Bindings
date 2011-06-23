package BaseObject;
use Carp;
use strict;
our $AUTOLOAD;

sub new {
	my ($class, $parent, $element) = @_;
	my $self = bless {
		_name => $element->name,
		_parent => $parent,
	}, $class;
	$self->_parse($element);
	return $self;
}

sub _parse {
	my ($self, $element) = @_;
	
	$self->{_children_aref} = [];
	$self->{_children_href} = {};
	
	# make sure all possible attributes and children exist
	my @allowed_attrs = $self->_allowed_attrs;
	for my $attr (@allowed_attrs) {
		(my $key = $attr)=~s/-/_/g;
		$self->{$key} = undef;
	}
	for my $c ($self->_allowed_children) {
		my $key = $self->_element_key($c);
		$self->{_children_href}{$key} = [];
	}
	
	# get attributes
	my @allowed_attrs = $self->_allowed_attrs;
	for my $attr (keys %{ $element->attrs }) {
		# verify attribute is allowed
		my $allowed;
		for my $check (@allowed_attrs) {
			next unless $attr eq $check;
			$allowed = 1;
			last;
		}
		
		# set if allowed
		if ($allowed) {
			(my $key = $attr)=~s/-/_/g;
			$self->{$key} = $element->attr($attr);
			next;
		}
		
		# uh-oh
		die "Unsupported attribute of $element->{name} element: $attr";
	}
	
	# get children
	my @allowed_children = $self->_allowed_children;
	my $content_as = $self->_content_as;
	for my $child (@{ $element->children }) {
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		if ($child->isa('SGML::Content')) {
			if ($content_as) {
				$self->add($content_as, $element);
			}
			next;
		}
		
		my $cn = $child->name;
		
		# check for a special handler
		if (my $subref = $self->_child_handler($cn)) {
			$self->$subref($child);
			next;
		}
		
		# verify child is allowed
		my $allowed;
		for my $check (@allowed_children) {
			next unless $cn eq $check;
			$allowed = 1;
			last;
		}
		
		# set if allowed
		if ($allowed) {
			$self->_add($child);
			next;
		}
		
		# uh-oh
		die "Unsupported child of $element->{name} element: $cn";
	}
}

sub _add {
	my ($self, $element) = @_;
	my $name = $element->name;
	
	my $key = $self->_element_key($name);
	my $class = $self->_element_class($name);
	
#print "Adding a $class to $self under $key\n";
	my $child = $class->new($self, $element);
	push @{ $self->{_children_aref} }, $child;
	push @{ $self->{_children_href}{$key} }, $child;
}

# used for getting child elements;
sub AUTOLOAD {
	my $self = shift;
	(my $name = $AUTOLOAD)=~ s/.*://;   # strip fully-qualified portion
	
	# check for an attr
	if (exists $self->{$name}) {
		return $self->{$name};
	}
	
	# check for children
	if (exists $self->{_children_href}{$name}) {
		return @{ $self->{_children_href}{$name} };
	}
	
	croak "No child named '$name' in $self";
}

sub _folder {
	my ($self) = @_;
	return $self->{_folder} if $self->{_folder};
	return $self->{_parent}->_folder;
}

sub _allowed_attrs {
	my ($self) = @_;
	no strict 'refs';
	return @{ ref($self) . '::allowed_attrs' };
}

sub _allowed_children {
	my ($self) = @_;
	no strict 'refs';
	return keys %{ ref($self) . '::allowed_children' };
}

sub _child_handler {
	my ($self, $name) = @_;
	no strict 'refs';
	return ${ ref($self) . '::child_handlers' }{$name};
}

sub _content_as {
	my ($self) = @_;
	no strict 'refs';
	return keys %{ ref($self) . '::want_content' };
}

sub _element_key {
	my ($self, $name) = @_;
	no strict 'refs';
	return ${ ref($self) . '::allowed_children' }{$name}{'key'};
}

sub _element_class {
	my ($self, $name) = @_;
	no strict 'refs';
	return ${ ref($self) . '::allowed_children' }{$name}{'class'};
}

1;
