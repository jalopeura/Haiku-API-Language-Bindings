# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(ApplicationKit InterfaceKit)) {
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

sub AppActivated {
	my ($self, $active) = @_;
warn "AppActivated ($active)";
}

sub QuitRequested {
	my ($self) = @_;
warn "QuitRequested";
	return $self->SUPER::QuitRequested();
}

sub ReadyToRun {
	my ($self) = @_;
warn "ReadyToRun";
}

sub MessageReceived {
	my ($self, $message) = @_;
warn $message;
	$self->SUPER::MessageReceived($message);
}

package MyWindow;
use Haiku::CustomWindow;
use strict;
our @ISA = qw(Haiku::CustomWindow);

my $click_count;

sub MessageReceived {
	my ($self, $message) = @_;
	my $what = $message->what;
	my $text = unpack('A*', pack('L', $what));
#print "$what => $text\n";
	if ($what == 0x12345678) {
		$click_count++;
warn $click_count;
		$main::TestButton->SetLabel("Clicks: $click_count");
		return;
	}
	$self->SUPER::MessageReceived($message);
}

package main;
use strict;

$TestApp = new MyApplication("application/language-binding") or die "Unable to create app: $Haiku::ApplicationKit::Error";

#print $TestApp,"\n";

my $wrect = new Haiku::Rect(50,50,250,250);

#print $wrect,"\n";

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
	B_CURRENT_WORKSPACE,	# workspace
);

$TestButton = new Haiku::Button(
	new Haiku::Rect(10,10,110,100),	# frame
	"TestButton",	# name
	"Click Me",	# label
	new Haiku::Message(0x12345678),	# message
	B_FOLLOW_LEFT | B_FOLLOW_TOP,	# resizingMode
	B_WILL_DRAW | B_NAVIGABLE,	# flags
);

$TestWindow->AddChild(
	$TestButton,	# view
	0,	# sibling
);

$TestWindow->Show;

$TestApp->Run;



