package SGML::Element;
use strict;

sub new {
	my ($class, $tag) = @_;
	my ($otag, $name, %attrs);
	$otag = $tag;
	$tag=~s:/$::;
	$tag=~s/(\S+)\s*// and $name = $1;
	
	while (length $tag) {
		my $key;
		$tag=~s/([^\s=]+)=// and $key = $1;
		
		my $value;
		# quoted value
		if ($tag=~s/^(["'])//) {
			my $q = $1;
			while (1) {
				$tag=~s/([^$q]+)// and $value .= $1;
				$tag=~s/^$q// or
					die "No closing quote for attribute '$key' in tag '$otag'";
					
				if ($value=~s/\\$//) {
					$value .= $q;
					next;
				}
				last;
			}
			$tag=~s/\s+//;
		}
		else {
			$tag=~s/(\S+)\s*// and $value = $1;
		}
		
		$attrs{$key} = $value;
	}
	
	my $self = bless {
		name => $name,
		attrs => \%attrs,
		children => [],
	}, $class;
	return $self;
}

sub addchild {
	my ($self, $child) = @_;
	push @{ $self->{children } }, $child;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub attrs {
	my ($self) = @_;
	return $self->{attrs};
}

sub attr {
	my ($self, $key) = @_;
	return $self->{attrs}{$key};
}

sub children {
	my ($self) = @_;
	return $self->{children};
}

package SGML::Comment;
use strict;

sub new {
	my ($class, $value) = @_;
	$value=~s/^!--//; $value=~s/--$//;
	my $self = bless {
		value => $value,
	}, $class;
	return $self;
}

sub value {
	my ($self) = @_;
	return $self->{value};
}

package SGML::Content;
use strict;

sub new {
	my ($class, $value) = @_;
	my $self = bless {
		value => $value,
	}, $class;
	return $self;
}

sub value {
	my ($self) = @_;
	return $self->{value};
}

package SGML::Parser;
use strict;

our @ISA = qw(SGML::Element);

# can operate on string, filename, or filehandle

sub new {
	my ($class, @options) = @_;
	
	my $self = bless {
		input => [],
		buffer => '',
	}, $class;
	
	while (@options) {
		my $type = shift @options;
		my $value = shift @options;
		if ($type eq 'string') {
			$self->addstring($value);
			next;
		}
		if ($type eq 'handle') {
			$self->addhandle($value);
			next;
		}
		if ($type eq 'filename') {
			$self->addfilename($value);
			next;
		}
	}
	
	if (@{ $self->{input} }) {
		$self->parse;
	}
	
	return $self;
}

sub addstring {
	my ($self, $string) = @_;
	if (ref $string) {
		push @{ $self->{input} }, $string;
		return;
	}
	push @{ $self->{input} }, \$string;
}

sub addhandle {
	my ($self, $handle) = @_;
	push @{ $self->{input} }, $handle;
}

sub addfilename {
	my ($self, $filename) = @_;
	push @{ $self->{input} }, $filename;
}

sub parse {
	my ($self) = @_;
	
	$self->{children} = [];
	my @elements = ($self);
	while (1) {
		# check for comments
		if ($self->{buffer}=~m/^<!--/) {
			my $cmt;
			until ($self->{buffer}=~s/^<(!--.+--)>//ms and $cmt = $1) {
				$self->extend_buffer or die "Unfinished comment";
			}
			my $c = new SGML::Comment($cmt);
			$elements[-1]->addchild($c);
			next;
		}
		
		# try to get a tag out of the buffer
		$self->{buffer}=~s/^<([^>]+)>//;
		if ($1) {
			my $tag = $1;
			$tag=~s/^\s+//; $tag=~s/\s+$//;
			
			# if this is a closing tag, verify that it matches the tag on the stack
			if ($tag=~s:^/::) {
				my $current = $elements[-1]->name;
				if ($current ne $tag) {
					die "Bad SGML in $self->{current_filename}: current element is $current, but found closing tag for $tag";
				}
				pop @elements;
				next;
			}
			
			# otherwise, create an element for this tag
			my $e = new SGML::Element($tag);
			$elements[-1]->addchild($e);
			
			# if this tag needs a closer, push it on the stack
			unless ($tag=~s:/$::) {
				push @elements, $e;
			}
			next;
		}
		
		# try to get some non-tag content out of the buffer
		$self->{buffer}=~s/^([^<]+)//;
		if ($1) {
			my $c = new SGML::Content($1);
			$elements[-1]->addchild($c);
			next;
		}
		
		# try to extend the buffer
		if ($self->extend_buffer) {
			next;
		}
		
		# if we got here, we have no more tags, no more content, and no more buffer
		last;
	}
	
	# try to get some tags out of the buffer
	# if not possible, try to read some more into the buffer
}

sub extend_buffer {
	my ($self) = @_;
	
	# if there's no more input, we're done
	unless (@{ $self->{input} }) {
		return undef;
	}
	
	my $next = $self->{input}[0];
	$self->{current_filename} ||= ref($next);
	
	if (not ref $next) {
		open my $fh, $next or die "Unable to open filename '$next': $!";
		$self->{current_filename} = $next;
		$self->{input}[0] = $fh;
		$next = $fh;
	}
	
	# if this is a filehandle, read a line and add it to the buffer
	if (ref($next) eq 'GLOB') {
		my $line = <$next>;
		if (not defined $line) {
			close $next;
			undef $self->{current_filename};
			shift @{ $self->{input} };
		}
		$self->{buffer} .= $line;
		return 1;
	}
	
	# if this is a scalar ref, add it to the buffer
	if (ref($next) eq 'SCALAR') {
		$self->{buffer} .= $$next;
		shift @{ $self->{input} };
		return 1;
	}
	
	# uh-oh - we should only have GLOBs and SCALARs on our input stack
	die "Unknown input: $next";
}

sub addchild {
	my ($self, $child) = @_;
	push @{ $self->{children } }, $child;
}

sub children {
	my ($self) = @_;
	return $self->{children};
}

sub root {
	my ($self) = @_;
	for my $c (@{ $self->{children} }) {
		# skip comments and content (whitespace)
		# and use the first element as the root
		next unless $c->isa('SGML::Element');
		return $c;
	}
	return undef;
}

1;
