package BaseObject;
use Carp;
use strict;
our $AUTOLOAD;

sub _has_doc {}
sub _attributes {}
sub _children {}
sub _defaults {}
sub _required_data {}
sub _bool_attrs {}

sub check_required_data {
	my ($self) = @_;
	
	my %d = $self->_defaults;
	my @r = $self->_required_data;
	for my $r (@r) {
		next if $self->{$r};
		next if $self->{$r} = $d{$r};
		
		$self->dump($self);
		die "Required data '$r' not found in $self";
	}
	
	for my $attr ($self->_bool_attrs) {
		my $val = $self->{$attr};
		if ($val eq 'true' or $val eq 'yes' or $val+0) {
			$self->{$attr} = 1;
		}
		else {
			$self->{$attr} = 0;
		}
	}
	
	my %c = $self->_children;
	my @c = map { $c{$_}{key} } keys %c;
	for my $k (@c) {
		my $c = $self->{$k};
		next unless $c;
		
		if (ref($c) eq 'ARRAY') {
			for my $e (@$c) {
				$e->check_required_data;
			}
		}
		else {
			$c->check_required_data;
		}
	}
}

sub has {
	my ($self, $key) = @_;
	if (exists $self->{$key}) {
		if (ref($self->{$key}) eq 'ARRAY') {
			return @{ $self->{$key} };
		}
		return 1;
	}
	return undef;
}

sub dump {
	my ($self) = @_;
	
	print STDERR $self,"\n";
	for my $k ($self->_attributes) {
		print STDERR "\t$k => $self->{$k}\n";
	}
}

sub xdump {
	my ($self, $value, $seen, $level) = @_;
	
	$seen ||= {};
	
	print STDERR $value,"\n";
	
	my $ref = ref($value);
	return unless $ref;
	
	if ($ref eq 'SCALAR') {
		$self->dump_sref($value, $seen, $level+1);
		return;
	}
	if ($ref eq 'ARRAY') {
		$self->dump_aref($value, $seen, $level+1);
		return;
	}
	if ($ref eq 'HASH') {
		$self->dump_href($value, $seen, $level+1);
		return;
	}
	
	if ($value->isa('BaseObject')) {
		if ($seen->{$value}) {
			print STDERR "\t" x ($level+1), "(previously dumped)\n";
			next;
		}
		$seen->{$value} = 1;
		$self->dump_href($value, $seen, $level+1);
	}
	
}

sub dump_aref {
	my ($self, $value, $seen, $level) = @_;
	
	my $pfx = "\t" x $level;
	for my $i (0..$#$value) {
		print STDERR $pfx, $i, "\t";
		$self->dump($value->[$i], $seen, $level);
	}
}

sub dump_href {
	my ($self, $value, $seen, $level) = @_;
	
	my $pfx = "\t" x $level;
	for my $k (sort keys %$value) {
		print STDERR $pfx, $k, "\t";
		$self->dump($value->{$k}, $seen, $level);
	}
}

# used for getting child elements;
sub AUTOLOAD {
	my $self = shift;
	(my $name = $AUTOLOAD)=~ s/.*://;   # strip fully-qualified portion
	
	unless (ref $self) {
		my $c = join(':::', caller);
		warn "Function $AUTOLOAD called on $self from $c";
	}
	
	if (exists $self->{$name}) {
		if (ref($self->{$name}) eq 'ARRAY') {
			return @{ $self->{$name} };
		}
		return $self->{$name};
	}
	
	my $c = join(':::', caller);
	croak "No child named '$name' in $self ($c)";
}

1;

__END__

BaseObject's descendant classes are used as data holders. The parsers use them as base classes and fill the data slots. Then the generators rebless the underlying hashes into another class and use the data.
