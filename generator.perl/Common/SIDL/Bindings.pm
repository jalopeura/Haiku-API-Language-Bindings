use Common::Bindings;
use Common::SIDL::BaseObject;

package SIDL::Bindings;
use File::Spec;
use Common::SIDL::SGML;
use Common::SIDL::Bundle;
use Common::SIDL::Include;
use Common::SIDL::Link;
use Common::SIDL::Types;
use strict;
our @ISA = qw(Bindings SIDL::BaseObject);

my %child_handlers = (
	import => \&_import,
);
sub _child_handlers { %child_handlers }

sub new {
	my ($class, %options) = @_;
	my ($vol, $dir, $path) = File::Spec->splitpath($options{source});
	my $folder = File::Spec->canonpath($dir);
	
	my $self = bless {
		_name   => 'root',
		_folder => $folder,
		_filename => [ $options{source} ],
		_parser => new SGML::Parser(filename => $options{source}),
		_imports_as_bundles => $options{imports_as_bundles},
		source_type_prefix => 'SIDL',
	}, $class;
	
print "Parsing $options{source}\n";
	my $root = $self->{_parser}->root;
	$self->_parse($root);
	
	return $self;
}

sub _import {
	my ($self, $element) = @_;
	
	if ($self->{_imports_as_bundles}) {
		my %allowed_children = $self->_children;
		$self->_add($element, $allowed_children{'bundle'});
		return;
	}
	
	for my $file (@{ $element->children }) {
		# ignore content and comments
		next if $file->isa('SGML::Content');
		next if $file->isa('SGML::Comment');
		
		# only support 'file' elements as children
		my $in = $file->name;
		$in eq 'file' or
			die "Unsupported child of import element: $in";
		
		my $filename = File::Spec->canonpath(
			File::Spec->catfile($self->{_folder}, $file->attr('name'))
		);
		$self->{_parser}->addfilename($filename);
		$self->{_parser}->parse;
		
		# before we parse our children, we need to adjust our path
		# to reflect the location of the file we just parsed
		$self->{_folder_stack} ||= [];
		push @{ $self->{_folder_stack} }, $self->{_folder};
		
		my ($vol, $path, $file) = File::Spec->splitpath($filename);
		$self->{_folder} = File::Spec->catpath($vol, $path);
		
		$self->_parse_children($self->{_parser}->root);
		
		$self->{_folder} = pop @{ $self->{_folder_stack} };
		
#		my $elements = $self->{_parser}->root->children;
#		for my $element (@$elements) {
#			next if $element->isa('SGML::Content');
#			next if $element->isa('SGML::Comment');
#			$self->_add($element);
#		}
		
		next;
	}
}

package SIDL::Binding;
use Common::SIDL::Functions;
use Common::SIDL::Properties;
use Common::SIDL::Operators;
use Common::SIDL::Constants;
use Common::SIDL::Globals;
use strict;
our @ISA = qw(Binding SIDL::BaseObject);

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
