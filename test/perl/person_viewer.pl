#!perl
# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

use Haiku::SupportKit;
use Haiku::ApplicationKit;
use Haiku::InterfaceKit;
use strict;

our ($TestApp, $TestWindow, $TestButton);

package PersonViewerApplication;
use Haiku::CustomApplication;
use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use strict;
our @ISA = qw(Haiku::CustomApplication);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);

	$self->{window} = new PersonViewerWindow(
		new Haiku::Rect(50,50,650,450),	# frame
		"Person Viewer",	# title
		B_TITLED_WINDOW,	# type
		B_QUIT_ON_WINDOW_CLOSE,	# flags
	);
	
	$self->{window}->Show;
	
	return $self;
}

sub ArgvReceived {
	my ($self, $args) = @_;
	# 0 is executable name (perl)
	# 1 is perl file
	# 2 is person file
	my $filename = $args->[2] or do {
		Haiku::Alert->new(
			"Usage Error",
			"Usage: $0 <person_file>",
			"Ok",
		)->Go;
		exit;
	};
	$self->{window}->SetPerson($filename);
}

package PersonViewerWindow;
use Haiku::CustomWindow;
use Haiku::View qw(B_FOLLOW_LEFT B_FOLLOW_TOP B_WILL_DRAW B_NAVIGABLE);
use strict;
our @ISA = qw(Haiku::CustomWindow);

our @Attributes = qw(
	META:name  META:nickname META:group
	META:address META:city META:state META:zip META:country
	META:email META:hphone META:wphone META:fax META:url
);
our %Attributes = (
	'META:name' => {
		label => 'Name',
		object_name => 'name',
	},
	'META:nickname' => {
		label => 'Nickname',
		object_name => 'nickname',
	},
	'META:group' => {
		label => 'Group',
		object_name => 'group',
	},
	'META:address' => {
		label => 'Address',
		object_name => 'address',
	},
	'META:city' => {
		label => 'City',
		object_name => 'city',
	},
	'META:state' => {
		label => 'State',
		object_name => 'state',
	},
	'META:zip' => {
		label => 'Zip/Postal Code',
		object_name => 'zip',
	},
	'META:country' => {
		label => 'Country',
		object_name => 'country',
	},
	'META:email' => {
		label => 'Email',
		object_name => 'email',
	},
	'META:hphone' => {
		label => 'Home Phone',
		object_name => 'phone',
	},
	'META:wphone' => {
		label => 'Work Phone',
		object_name => 'wphone',
	},
	'META:fax' => {
		label => 'Fax',
		object_name => 'fax',
	},
	'META:url' => {
		label => 'Website',
		object_name => 'url',
	},
);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	my $left   = 5;
	my $top    = 5;
	my $width  = 300;
	my $height = 20;
	my $vgap   = 5;
	
	for my $attr (@Attributes) {
		$self->AddAttribute($attr,
			new Haiku::Rect($left, $top, $left+$width, $top+$height)
		);
		$top += $height + $vgap;
	}
	
	return $self;
}

sub AddAttribute {
	my ($self, $attr, $frame) = @_;
	
	my ($label, $on) = @{ $Attributes{$attr} }{qw(label object_name)};
	
	# first name
	$self->{$on} = new Haiku::TextControl(
		$frame,	# frame
		$on,	# name
		$label,	# label
		"*$on*",	# text
		undef,			# message not needed for now
		# remaining parameters use defaults
	);
	$self->AddChild($self->{$on});
}

sub SetPerson {
	my ($self, $file) = @_;
	
	# for now, we cheat by using the command-line utility
	# will be changed to use Haiku::Node when the Node bindings are ready
	(my $esc_file = $file)=~s/([\s])/\\$1/g;
	
	$self->Lock;
	
	for my $attr (@Attributes) {
		my $cmd = qq(catattr $attr $esc_file);
		my ($retfile, $type, $value) = split /\s*:\s*/, `$cmd`;
		
		my $on = $Attributes{$attr}{object_name};
		$self->{$on}->SetText($value . "\0");
	}
	
	$self->Unlock;
}

package main;
use strict;

my $App = new PersonViewerApplication("application/person-viewer") or die "Unable to create app: $Haiku::ApplicationKit::Error";

$App->Run;
