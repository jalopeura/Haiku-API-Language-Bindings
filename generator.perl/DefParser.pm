use SGML::Parser;
use SGML::Util qw(SGMLparse_attr_spec);
use strict;

package DefParser;
our @ISA = qw(SGML::Parser);

sub parse {
	my ($self, $infile, $outfolder) = @_;
	
	$self->{tag_stack} = [];
	
	($self->{cwd} = $infile)=~s:/[^/]+$::;
	
	for my $g (@{ $self->{generators} }) {
		$g->start_processing($infile, $outfolder);
	}
	
	open my $in, $infile or die "Unable to read file '$infile': $!";
	my $ret = $self->parse_data($in,$infile);
	close $in;
	
	for my $g (@{ $self->{generators} }) {
		$g->end_processing($infile, $outfolder);
	}
	
	return $ret;
}

sub generators {
	my ($self, @g) = @_;
	if (@g) {
		$self->{generators} = [ @g ];
	}
	return @{ $self->{generators} };
}

sub start_tag {
	my ($self, $gi, $attr_spec) = @_;
	
	push @{ $self->{tag_stack} }, $gi;
	my $found;
		
	# here do end tags for tags without closers
	if ($attr_spec=~m:/$:) {
		$self->end_tag($gi);
	}
	
	my %attrs = SGML::Util::SGMLparse_attr_spec($attr_spec);
	
	if ($gi eq 'import') {
		my $old_cwd = $self->{cwd};
		my $file = "$old_cwd/$attrs{file}";
		($self->{cwd} = $file)=~s:/[^/]+$::;
		
		open my $in, $file or die "Unable to read file '$file': $!";
		my $ret = $self->parse_data($in,$file);
		close $in;
		
		$self->{cwd} = $old_cwd;
		return;
	}
	
	if ($gi eq 'include') {
		my @i = split /\s*,\s*/, $attrs{files};
		for my $g (@{ $self->{generators} }) {
			$g->include(@i);
		}
		return;
	}
	
	if ($gi eq 'link') {
		my @i = split /\s*,\s*/, $attrs{files};
		for my $g (@{ $self->{generators} }) {
			$g->linklib(@i);
		}
		return;
	}
	
	if ($gi eq 'bindings') {
		if ($attrs{bundle}) {
			for my $g (@{ $self->{generators} }) {
				$g->bundle($attrs{bundle});
			}
		}
		return;
	}
	
	if ($gi eq 'binding') {
		for my $g (@{ $self->{generators} }) {
			$g->start_class(%attrs);
		}
		return;
	}
	
	if ($gi eq 'constructor') {
		$self->{constructor_attrs} = \%attrs;
		return;
	}
	
	if ($gi eq 'method') {
		$self->{method_attrs} = \%attrs;
		return;
	}
	
	if ($gi eq 'event') {
		$self->{event_attrs} = \%attrs;
		return;
	}
	
	if ($gi eq 'params') {
		$self->{params} = [];
		return;
	}
	
	if ($gi eq 'param') {
		push @{ $self->{params} }, \%attrs;
		return;
	}
	
	if ($gi eq 'return') {
		$self->{return} = \%attrs;
		return;
	}
	
	if ($gi eq 'property') {
		for my $g (@{ $self->{generators} }) {
			$g->property(%attrs);
		}
		return;
	}
	
	if ($gi eq 'constant') {
		for my $g (@{ $self->{generators} }) {
			$g->constant(%attrs);
		}
		return;
	}
	
	if ($gi eq 'type') {
		for my $g (@{ $self->{generators} }) {
			$g->type(%attrs);
		}
		return;
	}
	
	# no special processing required
	if ($gi eq 'methods' or
		$gi eq 'events' or
		$gi eq 'destructor' or
		$gi eq 'properties' or
		$gi eq 'constants' or
		$gi eq 'types') {
		return;
	}
	
	unless ($found) {
		print join(':::', 'start_tag', @_),"\n";
	}
#	start_tag is called for start tags. $gi is the generic indentifier of the start tag. $attr_spec is the attribute specification list string. The SGMLparse_attr_spec function defined in SGML::Util can be used to parse the string into name/value pairs. 
}

sub end_tag {
	my ($self, $gi) = @_;	# generic identifier
	
	my $tag = pop @{ $self->{tag_stack} };
	$tag eq $gi or warn "Tag mismatch: $tag was last left open, but $gi is closing";
	
	# no special processing required
	if ($gi eq 'bindings' or
		$gi eq 'include' or
		$gi eq 'link' or
		$gi eq 'import' or
		$gi eq 'methods' or
		$gi eq 'events' or
		$gi eq 'params' or
		$gi eq 'param' or
		$gi eq 'return' or
		$gi eq 'properties' or
		$gi eq 'property' or
		$gi eq 'constants' or
		$gi eq 'constant' or
		$gi eq 'types' or
		$gi eq 'type') {
		return;
	}
	
	if ($gi eq 'binding') {
		for my $g (@{ $self->{generators} }) {
			$g->end_class();
		}
		return;
	}
	
	if ($gi eq 'constructor') {
		for my $g (@{ $self->{generators} }) {
			$g->constructor($self->{constructor_attrs}, @{ $self->{params} });
		}
		undef $self->{params};
		return;
	}
	
	if ($gi eq 'destructor') {
		for my $g (@{ $self->{generators} }) {
			$g->destructor();
		}
		return;
	}
	
	if ($gi eq 'method') {
		for my $g (@{ $self->{generators} }) {
			$g->method($self->{method_attrs}, $self->{return}, @{ $self->{params} });
		}
		undef $self->{params};
		undef $self->{return};
		return;
	}
	
	if ($gi eq 'event') {
		for my $g (@{ $self->{generators} }) {
			$g->event($self->{event_attrs}, $self->{return}, @{ $self->{params} });
		}
		undef $self->{params};
		undef $self->{return};
		return;
	}
		
	print join(':::', 'end_tag', @_),"\n";
#	end_tag is called when an end tag is encountered. The generic identifier of the end tag is passed in as an argument. The value may be the empty string if the end tag is a null end tag. 
}

# the SGML is set up so there shouldn't be any (non-whitespace) cdata
# so this doesn't do anything
sub cdata {
#	cdata is invoked when character data is encountered. The character data is passed into the method. Multiple lines of character data may generate multiple cdata calls. 
}

# no char refs in the SGML
# so this doesn't do anything
sub char_ref {
#	char_ref is invoked when a character reference is encountered. The number/name of the character reference is passed in as an argument. 
}

# just ignore comments
sub comment_decl {
#	my ($self, $comments) = @_;	# arrayref of comment blocks
#	comment_decl is called when a comment declaration is parsed. The passed in argument is a reference to an array containing the comment blocks defined in the declaration. 
}

# no entity refs in the SGML
# so this doesn't do anything
sub entity_ref {
#	entity_ref is called for entity references. The name of the entity is passed in as an argument. If any data is returned by this method, the data will be prepended to the parse buffer and parsed. 
}

# no ignored sections in the SGML
# so this doesn't do anything
sub ignored_data {
#	ignored_data is called for data that is in an IGNORE marked section. 
}

# no marked section close in the SGML
# so this doesn't do anything
sub marked_sect_close {
#	marked_sect_close is called when a marked section close is encountered. 
}

# no marked section open in the SGML
# so this doesn't do anything
sub marked_sect_open {
#	marked_sect_open is called when a marked section open is encountered. The $status_keyword argument is the status keyword for the marked section (eg. INCLUDE, IGNORE). The $status_spec argument is the original status specification text. This may be equal to $status_keyword, or contain an parameter entity reference. If a parameter entity reference, the parm_entity_ref method was called to determine the value of the $status_keyword argument. 
}

# no parameter entity refs in the SGML
# so this doesn't do anything
sub parm_entity_ref {
#	parm_entity_ref is called to resolve parameter entity references. Currently, it is only invoked if a parameter entity reference is encountered in a marked section open. The return value should contain the value of the parameter entity reference. 
}

# no processing instructions in the SGML
# so this doesn't do anything
sub processing_inst {
#	processing_inst is called for processing instructions. $data is the content of the processing instruction. 
}

1;
