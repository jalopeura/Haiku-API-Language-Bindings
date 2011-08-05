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

1;
