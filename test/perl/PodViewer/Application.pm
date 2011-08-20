package PodViewer::Application;
use Haiku::ApplicationKit;
use PodViewer::Window;
use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use strict;
our @ISA = qw(Haiku::CustomApplication);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new("application/x-podviewer", @args);

	$self->{window} = new PodViewer::Window(
		new Haiku::Rect(50,50,250,250),	# frame
		"POD",	# title
		B_TITLED_WINDOW,	# type
		B_QUIT_ON_WINDOW_CLOSE,	# flags
	);
	
	$self->{window}->Show;
	
	return $self;
}

sub ArgvReceived {
	my ($self, $args) = @_;
#warn "\ArgvReceived($self, ", join(', ', @$args), ")\n\n";
	$self->SUPER::ArgvReceived($args);
}

sub QuitRequested {
	my ($self) = @_;
#warn "\nQuitRequested ($self)\n\n";
	# need to get rid of these explicitly now, or we'll
	# have an unreferenced scalar issue later
	$self->{window}{parser}->errorsub(undef);	# holds a reference to window
	undef $self->{window};
	return $self->SUPER::QuitRequested();
}

1;
