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

package MyApplication;
use Haiku::CustomApplication;
use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use strict;
our @ISA = qw(Haiku::CustomApplication);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);

	$self->{window} = new MyWindow(
		new Haiku::Rect(50,50,170,170),	# frame
		"Test Window",	# title
		B_TITLED_WINDOW,	# type
		B_QUIT_ON_WINDOW_CLOSE,	# flags
	);
	
	$self->{window}->Show;
	
	return $self;
}

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
	# need to get rid of this explicitly now, or we'll
	# have an unreferenced scalar issue later
	undef $self->{window};
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
use Haiku::View qw(B_FOLLOW_LEFT B_FOLLOW_TOP B_WILL_DRAW B_NAVIGABLE);
use strict;
our @ISA = qw(Haiku::CustomWindow);

my $click_count;
my $message_count;

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	$self->{button} = new Haiku::Button(
		new Haiku::Rect(10,10,110,110),	# frame
		"TestButton",	# name
		"Click Me",	# label
		new Haiku::Message(0x12345678),	# message
		B_FOLLOW_LEFT | B_FOLLOW_TOP,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
	);
	
	$self->AddChild($self->{button}, 0);
	
	return $self;
}

sub MessageReceived {
	my ($self, $message) = @_;
	$self->{message_count}++;
	my $what = $message->what();
#my $text = unpack('A*', pack('L', $what));
#print "$what => $text\n";
	if ($what == 0x12345678) {
		$self->{click_count}++;
		$self->{button}->SetLabel("$self->{click_count} of $self->{message_count}\0");
		return;
	}
	$self->SUPER::MessageReceived($message);
}

package main;
use strict;

$Haiku::ApplicationKit::DEBUG = 0;
$Haiku::InterfaceKit::DEBUG = 0;

$TestApp = new MyApplication("application/language-binding") or die "Unable to create app: $Haiku::ApplicationKit::Error";

$TestApp->Run;

print $TestApp->{window},"\n";
