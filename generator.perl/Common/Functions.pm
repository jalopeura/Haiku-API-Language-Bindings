package Function;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		params => new Params,
	}, $class;
	
	# [function] element can have the following attributes:
	# name, overload-name
	for my $attr (qw(name overload-name)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# [function] element can have the following child elements:
	# params, return
	for my $child (@{ $element->children }) {
		# bundles has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		if ($cn eq 'params') {
			$self->{params}->add($child);
			next;
		}
		
		if ($cn eq 'return') {
			$self->{return} = new Return($child);
			next;
		}
		
		die "Unsupported child of [function] element: $cn";
	}
	
	return $self;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub overload_name {
	my ($self) = @_;
	return $self->{'overload-name'};
}

sub params {
	my ($self) = @_;
	my @ret = $self->{params}->params;
	if ($self->{return}) {
		push @ret, $self->{return};
	}
	return @ret;
}

package Constructor;
use strict;
our @ISA = qw(Function);

package Destructor;
use strict;
our @ISA = qw(Function);

package Method;
use strict;
our @ISA = qw(Function);

package Event;
use strict;
our @ISA = qw(Function);

package Static;
use strict;
our @ISA = qw(Function);

package Plain;
use strict;
our @ISA = qw(Function);

package Functions;
use Common::Params;
use strict;

sub new {
	my ($class, @elements) = @_;
	my $self = bless {
		constructors => [],
		destructors => [],
		methods => [],
		events => [],
		statics => [],
		plains => [],
	}, $class;
	
	$self->add(@elements);
	
	return $self;
}

sub add {
	my ($self, @elements) = @_;
	
	# functions element can have the following child elements:
	# constructor, destructor, method, event, static
	for my $element (@elements) {
		for my $child (@{ $element->children }) {
			# functions has no content, so Content elements are just whitespace
			next if $child->isa('SGML::Content');
			
			# ignore comments
			next if $child->isa('SGML::Comment');
			
			my $cn = $child->name;
			
			if ($cn eq 'constructor') {
				push @{ $self->{constructors} }, new Constructor($child);
				next;
			}
			
			if ($cn eq 'destructor') {
				push @{ $self->{destructors} }, new Destructor($child);
				next;
			}
			
			if ($cn eq 'method') {
				push @{ $self->{methods} }, new Method($child);
				next;
			}
			
			if ($cn eq 'event') {
				push @{ $self->{events} }, new Event($child);
				next;
			}
			
			if ($cn eq 'static') {
				push @{ $self->{statics} }, new Static($child);
				next;
			}
			
			if ($cn eq 'static') {
				push @{ $self->{plains} }, new Plain($child);
				next;
			}
			
			die "Unsupported child of links element: $cn";
		}
	}
}

sub constructors {
	my ($self) = @_;
	return @{ $self->{constructors} };
}

sub destructor {
	my ($self) = @_;
	unless (@{ $self->{destructors} }) {
		return undef;
	}
	return $self->{destructors}[0];
}

sub methods {
	my ($self) = @_;
	return @{ $self->{methods} };
}

sub events {
	my ($self) = @_;
	return @{ $self->{events} };
}

sub statics {
	my ($self) = @_;
	return @{ $self->{statics} };
}

sub plains {
	my ($self) = @_;
	return @{ $self->{plains} };
}

1;
