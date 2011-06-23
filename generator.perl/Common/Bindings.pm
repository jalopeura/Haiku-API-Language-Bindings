package Bindings;
use File::Spec;
use Common::SGML;
use Common::Bundles;
use Common::Includes;
use Common::Links;
use Common::Types;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(name);
our %allowed_children = (
	bundle => {
		key => 'bundles',
		class => 'Bundle',
	},
	includes => {
		key => 'includes_collection',
		class => 'Includes',
	},
	links => {
		key => 'links_collection',
		class => 'Links',
	},
	types => {
		key => 'types_collection',
		class => 'Types',
	},
	binding => {
		key => 'bindings',
		class => 'Binding',
	},
);
our %child_handlers = (
	imports => \&_import,
);

sub new {
	my ($class, %options) = @_;
	
	my ($vol, $dir, $path) = File::Spec->splitpath($options{source});
	my $folder = File::Spec->canonpath($dir);
	
	my $self = bless {
		_name   => 'root',
		_folder => $folder,
	}, $class;
	
print "Parsing $options{source}\n";
	$self->{_parser} = new SGML::Parser(filename => $options{source});
	my $root = $self->{_parser}->root;
	
	$self->_parse($root);
	$self->{version} ||= '0.01';
	
	return $self;
}

sub _import {
	my ($self, $element) = @_;
	for my $import (@{ $element->children }) {
		# ignore content and comments
		next if $import->isa('SGML::Content');
		next if $import->isa('SGML::Comment');
		
		# only support 'import' elements as children
		my $in = $import->name;
		$in eq 'import' or
			die "Unsupported child of imports element: $in";
		
		my $filename = File::Spec->canonpath(
			File::Spec->catfile($self->{_folder}, $import->attr('file'))
		);
		$self->{_parser}->addfilename($filename);
		$self->{_parser}->parse;
		
		my $elements = $self->{_parser}->root->children;
		for my $element (@$elements) {
			next if $element->isa('SGML::Content');
			next if $element->isa('SGML::Comment');
			$self->_add($element);
		}
		
		next;
	}
}

package Binding;
use Common::BaseObject;
use Common::Functions;
use Common::Properties;
use Common::Constants;
use Common::Doc;
use strict;
our @ISA = qw(BaseObject);

our $content_as = '';
our @allowed_attrs = qw(source source-inherits target target-inherits must-not-delete version);
our %allowed_children = (
	functions => {
		key => 'functions_collection',
		class => 'Functions',
	},
	properties => {
		key => 'properties_collection',
		class => 'Properties',
	},
	constants => {
		key => 'constants_collection',
		class => 'Constants',
	},
);

# some shortcut functions

sub constructors {
	my ($self) = @_;
	my @ret;
	for my $functions ($self->functions_collection) {
		push @ret, $functions->constructors;
	}
	return @ret;
}

# should only be one destructor, so find first one
sub destructor {
	my ($self) = @_;
	for my $functions ($self->functions_collection) {
		my @d = $functions->destructors;
		return $d[0];
	}
	return undef;
}

sub methods {
	my ($self) = @_;
	my @ret;
	for my $functions ($self->functions_collection) {
		push @ret, $functions->methods;
	}
	return @ret;
}

sub events {
	my ($self) = @_;
	my @ret;
	for my $functions ($self->functions_collection) {
		push @ret, $functions->events;
	}
	return @ret;
}

sub statics {
	my ($self) = @_;
	my @ret;
	for my $functions ($self->functions_collection) {
		push @ret, $functions->statics;
	}
	return @ret;
}

sub plains {
	my ($self) = @_;
	my @ret;
	for my $functions ($self->functions_collection) {
		push @ret, $functions->plains;
	}
	return @ret;
}

sub properties {
	my ($self) = @_;
	my @ret;
	for my $properties ($self->properties_collection) {
		push @ret, $properties->properties;
	}
	return @ret;
}

sub constants {
	my ($self) = @_;
	my @ret;
	for my $constants ($self->constants_collection) {
		push @ret, $constants->constants;
	}
	return @ret;
}

1;
