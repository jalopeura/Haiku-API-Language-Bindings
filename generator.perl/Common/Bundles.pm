package Bundle;
use strict;

our @ISA = qw(Bindings);

sub new {
	my ($class, $element, $folder) = @_;
	
#print <<INFO;
#Creating bundle from $element->{attrs}{file}
#INFO
	
	my $source = File::Spec->catfile($folder, $element->attr('file'));
	
	my $self = $class->SUPER::new(
		source => $source,
	);
	
	return $self;
}

package Bundles;
use strict;

sub new {
	my ($class, $folder, @elements) = @_;
	my $self = bless {
		folder => $folder,
		children => [],
	}, $class;
	
	$self->add(@elements);
	
	return $self;
}

sub add {
	my ($self, @elements) = @_;
	
	# bundles element can have the following child elements:
	# bundle
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# bundles has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'bundle') {
				push @{ $self->{children} }, new Bundle($child, $self->{folder});
				next;
			}
			
			die "Unsupported child of bundles element: $cn";
		}
	}
}

sub bundles {
	my ($self) = @_;
	return $self->{children};
}

1;
