# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

use Haiku::ApplicationKit;
use Haiku::InterfaceKit qw(
	B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE B_CURRENT_WORKSPACE
	B_FOLLOW_LEFT B_FOLLOW_TOP B_WILL_DRAW B_NAVIGABLE
);
use strict;

our ($TestApp, $TestWindow, $TestButton);

package MyApplication;
use Haiku::CustomApplication;
use strict;
our @ISA = qw(Haiku::CustomApplication);

sub ArgvReceived {
	my ($self, $args) = @_;
warn "\ArgvReceived($self, ", join(', ', @$args), ")\n\n";
	$self->SUPER::ArgvReceived($args);
}

sub AppActivated {
	my ($self, $active) = @_;
warn "\nAppActivated($self, $active)\n\n";
}

sub QuitRequested {
	my ($self) = @_;
warn "\nQuitRequested ($self)\n\n";
	return $self->SUPER::QuitRequested();
}

sub ReadyToRun {
	my ($self) = @_;
warn "\nReadyToRun($self)\n\n";
}

sub MessageReceived {
	my ($self, $message) = @_;
warn "\nMessageReceived($self, $message)\n\n";
	$self->SUPER::MessageReceived($message);
}

package MyWindow;
use Haiku::CustomWindow;
use strict;
our @ISA = qw(Haiku::CustomWindow);

my $click_count;
my $message_count;

sub MessageReceived {
	my ($self, $message) = @_;
#print "$self, $message\n";
	$message_count++;
#print tied($message->what()),"\n";
	my $what = $message->what();
	my $text = unpack('A*', pack('L', $what));
#print "$what => $text\n";
	if ($what == 0x12345678) {
		$click_count++;
#warn $click_count;
		$main::TestButton->SetLabel("$click_count of $message_count");
		return;
	}
	$self->SUPER::MessageReceived($message);
}

package main;
use strict;

$Haiku::ApplicationKit::DEBUG = 4;
$Haiku::InterfaceKit::DEBUG = 0;

$TestApp = new MyApplication("application/language-binding") or die "Unable to create app: $Haiku::ApplicationKit::Error";

print "\nTestApp: $TestApp (", $TestApp+0,")\n\n";

my $wrect = new Haiku::Rect(50,50,250,250);

print "\nwrect: $wrect (", $wrect+0,")\n\n";

# simple get
#my $l = $wrect->left;

# simple set
#$wrect->left = 20;

# set and get
#$l = $wrect->left = 20;
#print $l,"\n";

$TestWindow = new MyWindow(
	$wrect,	# frame
	"Test Window",	# title
	B_TITLED_WINDOW,	# type
	B_QUIT_ON_WINDOW_CLOSE,	# flags
);

print "\nTestWindow: $TestWindow(", $TestWindow+0, ")\n\n";

{
	my $win = new MyWindow(
		$wrect,	# frame
		"Test Window",	# title
		B_TITLED_WINDOW,	# type
		B_QUIT_ON_WINDOW_CLOSE,	# flags
	);
	
	print "\nwin: $win (", $win+0, ")\n\n";
}

#=pod

$TestButton = new Haiku::Button(
	new Haiku::Rect(10,10,110,110),	# frame
	"TestButton",	# name
	"Click Me",	# label
	new Haiku::Message(0x12345678),	# message
	B_FOLLOW_LEFT | B_FOLLOW_TOP,	# resizingMode
	B_WILL_DRAW | B_NAVIGABLE,	# flags
);

print "\nTestButton: $TestButton(", $TestButton+0,")\n\n";

$TestWindow->AddChild(
	$TestButton,	# view
	0,	# sibling
);

#=cut

$TestWindow->Show;

$TestApp->Run;

undef $wrect;
undef $TestButton;
undef $TestWindow;
undef $TestApp;

print "\nEnd of file\n\n";
