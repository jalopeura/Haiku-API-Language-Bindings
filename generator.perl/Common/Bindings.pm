use Common::BaseObject;

package Bindings;
use Common::Bundle;
use Common::Include;
use Common::Link;
use Common::Types;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(name version);
my %children = (
	bundle => {
		key => 'bundle',
		class => 'Bundle',
	},
	include => {
		key => 'include',
		class => 'Include',
	},
	link => {
		key => 'link',
		class => 'Link',
	},
	types => {
		key => 'types',
		class => 'Types',
	},
	binding => {
		key => 'bindings',
		class => 'Binding+',
	},
);
my %defaults = (
	version => '0.01',
);
my @required_data = qw(name version);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _children { %children }
sub _defaults { %defaults }
sub _required_data { @required_data }

sub new {
	my ($class, %options) = @_;
	$class = join('::', $options{source_type}, 'Bindings');
	my $module = join('::', 'Common', $class);
	eval "use $module";
	die if $@;
	my $self = $class->new(%options);
	return $self;
}

package Binding;
use Common::Functions;
use Common::Properties;
use Common::Constants;
use strict;
our @ISA = qw(BaseObject);

my @attributes = qw(source source-inherits target target-inherits must-not-delete version);
my %children = (
	functions  => {
		key => 'functions',
		class => 'Functions',
	},
	properties => {
		key => 'properties',
		class => 'Properties',
	},
	operators  => {
		key => 'operators',
		class => 'Operators',
	},
	constants  => {
		key => 'constants',
		class => 'Constants',
	},
	globals  => {
		key => 'globals',
		class => 'Globals',
	},
);
my %defaults = (
	version => '0.01',
);
my @required_data = qw(source target version);
my @bool_attrs = qw(must-not-delete);

sub _has_doc { 1 }
sub _attributes { @attributes }
sub _children { %children }
sub _defaults { %defaults }
sub _required_data { @required_data }
sub _bool_attrs { @bool_attrs }

1;
