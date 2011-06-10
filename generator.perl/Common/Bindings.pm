package Binding;
use Common::Functions;
use Common::Properties;
use Common::Constants;
use strict;

sub new {
	my ($class, $element) = @_;
	my $self = bless {
		functions => new Functions,
		properties => new Properties,
		constants => new Constants,
	}, $class;
	
	# binding element can have the following attributes:
	# source source-inherits target target-inherits must-not-delete
	for my $attr (qw(source source-inherits target target-inherits must-not-delete)) {
		$self->{$attr} = $element->attr($attr);
	}
	
	# binding element can have the following child elements:
	# functions properties constants
	for my $child (@{ $element->children }) {
		# binding has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		if ($cn eq 'functions') {
			$self->{functions}->add($child);
			next;
		}
		
		if ($cn eq 'properties') {
			$self->{properties}->add($child);
			next;
		}
		
		if ($cn eq 'constants') {
			$self->{constants}->add($child);
			next;
		}
		
		die "Unsupported child of binding element: $cn";
	}
	return $self;
}

sub source {
	my ($self) = @_;
	return $self->{source};
}

sub source_inherits {
	my ($self) = @_;
	return $self->{'source-inherits'};
}

sub target {
	my ($self) = @_;
	return $self->{target};
}

sub target_inherits {
	my ($self) = @_;
	return $self->{'target-inherits'};
}

sub constructors {
	my ($self) = @_;
	$self->{functions}->constructors;
}

sub destructor {
	my ($self) = @_;
	$self->{functions}->destructor;
}

sub methods {
	my ($self) = @_;
	$self->{functions}->methods;
}

sub events {
	my ($self) = @_;
	$self->{functions}->events;
}

sub statics {
	my ($self) = @_;
	$self->{functions}->statics;
}

sub plains {
	my ($self) = @_;
	$self->{functions}->plains;
}

sub properties {
	my ($self) = @_;
	$self->{properties};
}

sub constants {
	my ($self) = @_;
	$self->{constants};
}

package Bindings;
use File::Spec;
use Common::SGML;
use Common::Bundles;
use Common::Includes;
use Common::Links;
use Common::Types;
use strict;

sub new {
	my ($class, %options) = @_;
	
	my ($vol, $dir, $path) = File::Spec->splitpath($options{source});
	my $folder = File::Spec->canonpath($dir);
	
	my $self = bless {
		folder   => $folder,
		bundles  => new Bundles($folder),
		includes => new Includes,
		links    => new Links,
		types    => new Types,
		bindings => [],
	}, $class;
	
	$self->{parser} = new SGML::Parser(filename => $options{source});
	my $root = $self->{parser}->root;
	
	# bindings element can have the following attributes:
	# name version
	for my $attr (qw(name version)) {
		$self->{$attr} = $root->attr($attr);
	}
	$self->{version} ||= '0.01';
#print <<INFO;
#Parsing bindings: $self->{name} ($self->{version})
#	print $self->{folder}
#INFO
	
	$self->parse_element($root);
	
	return $self;
}

sub parse_element {
	my ($self, $parent) = @_;
	
	# bindings element can have the following child elements:
	# bundles, imports, includes, links, types, binding
	for my $child (@{ $parent->children }) {
		# bindings has no content, so Content elements are just whitespace
		next if $child->isa('SGML::Content');
		
		# ignore comments
		next if $child->isa('SGML::Comment');
		
		my $cn = $child->name;
		
		# a bundle is parsed and generated separately from the current binding
		# it needs to know our paths so it can generate properly
		if ($cn eq 'bundles') {
			$self->{bundles}->add($child);
			next;
		}
		
		# an import is pulled in and generated along with the current binding
		if ($cn eq 'imports') {
			for my $import (@{ $child->children }) {
				# bundles has no content, so Content elements are just whitespace
				next if $import->isa('SGML::Content');
				
				# ignore comments
				next if $import->isa('SGML::Comment');
				
				my $in = $import->name;
				
				# imports element can have the following child elements:
				# import
				if ($in eq 'import') {
#print "Importing bindings from $import->{attrs}{file}\n";
					my $filename = File::Spec->canonpath(
						File::Spec->catfile($self->{folder}, $import->attr('file'))
					);
					$self->{parser}->addfilename($filename);
					$self->{parser}->parse;
					
					$self->parse_element($self->{parser}->root);
					
					next;
				}
				
				die "Unsupported child of imports element: $in";
			}
			next;
		}
		
		if ($cn eq 'includes') {
			$self->{includes}->add($child);
			next;
		}
		
		if ($cn eq 'links') {
			$self->{links}->add($child);
			next;
		}
		
		if ($cn eq 'types') {
			$self->{types}->add($child);
			next;
		}
		
		if ($cn eq 'binding') {
			push @{ $self->{bindings} }, new Binding($child);
			next;
		}
		
		die "Unsupported child of bindings element: $cn";
	}
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub version {
	my ($self) = @_;
	return $self->{version};
}

sub bundles {
	my ($self) = @_;
	return $self->{bundles};
}

sub includes {
	my ($self) = @_;
	return $self->{includes};
}

sub links {
	my ($self) = @_;
	return $self->{links};
}

sub types {
	my ($self) = @_;
	return $self->{types};
}

sub bindings {
	my ($self) = @_;
	unless (@{ $self->{bindings} }) {
		return undef;
	}
	return $self->{bindings};
}

1;
