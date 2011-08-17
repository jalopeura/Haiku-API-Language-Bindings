package SIDL::BaseObject;
#use Common::BaseObject;
use Carp;
use strict;
#our @ISA = qw(BaseObject);

sub _child_handlers {}
sub _content_as {}

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
	
	$self->_parse_attributes($element);
	$self->_parse_children($element);
}

sub _parse_attributes {
	my ($self, $element) = @_;
	
	my @allowed_attrs = $self->_attributes;
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
			$self->{$attr} = $element->attr($attr);
			next;
		}
		
		# uh-oh
		die "Unsupported attribute of $element->{name} element: $attr in file " . $self->_tree;
	}
}

sub _parse_children {
	my ($self, $element) = @_;
	
	my %allowed_children = $self->_children;
	# if multiples allowed, use an aref
	for my $c (keys %allowed_children) {
		if ($allowed_children{$c}=~/\+$/) {
			$self->{$c} = [];
		}
	}
	
	# get children
	my %handlers = $self->_child_handlers;
	for my $child (@{ $element->children }) {
		# ignore comments and content
		next if $child->isa('SGML::Comment') or $child->isa('SGML::Content');
		
		my $cn = $child->name;
		
		# do we have docs?
		if ($cn eq 'doc' and $self->_has_doc) {
			my @docs;
			for my $content (@{ $child->{children} }) {
				next unless $child->isa('SGML::Content');
				push @docs, $content->value;
			}
			$self->{doc} = \@docs;
			next
		}
		
		# check for a special handler
		if (my $subref = $handlers{$cn}) {
			$self->$subref($child);
			next;
		}
		
		# set if allowed
		if ($allowed_children{$cn}) {
			$self->_add($child, $allowed_children{$cn});
			next;
		}
		
		# uh-oh
		die "Unsupported child of $element->{name} element: $cn in file " . $self->_tree;
	}
}

sub _add {
	my ($self, $element, $childdef) = @_;
	
	my $class = $childdef->{class};
	
	my $use_aref = $class=~s/\+$//;
	
	$class = "SIDL::$class";	# use the SIDL version of this class
	
	if ($use_aref) {
		push @{ $self->{ $childdef->{key} } }, $class->new($self, $element);
	}
	elsif ($self->{ $childdef->{key} }) {
		$self->{ $childdef->{key} }->_parse_children($element);
#die "Adding where a singleton already exists ($class [$child], $self, $element) - what to do?";
#		my %grandchildren = $child->_children;
#print "$child, ", $element->name,"\n";
#		my $gcdef = $grandchildren{ $element->name };
#		$child->_add($element, $gcdef);
	}
	else {
		$self->{ $childdef->{key} } = $class->new($self, $element);
	}
}

sub _tree {
	my ($self) = @_;
	my $branch = $self->{_name};
	if ($self->{name}) {
		$branch .= " ($self->{name})";
	}
	elsif ($self->{source}) {
		$branch .= " ($self->{source})";
	}
	if ($self->{_parent}) {
		$branch = $self->{_parent}->_tree . ':' . $branch;
	}
	return $branch;
}

1;
