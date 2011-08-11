package People::PersonWindow;
use Haiku::SupportKit;
use Haiku::InterfaceKit;
use Haiku::View qw(B_FOLLOW_ALL B_WILL_DRAW B_NAVIGABLE);
use Haiku::ScrollBar qw(B_V_SCROLL_BAR_WIDTH B_H_SCROLL_BAR_HEIGHT);
use People::PersonView;
use strict;
our @ISA = qw(Haiku::CustomWindow);

use constant DO_SAVE       => 0xffff0001;
use constant DO_REVERT     => 0xffff0001;

my $horizontal_scroll = 0;
my $vertical_scroll = 1;

sub new {
	my ($class, $parent, $node, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	$self->{parent} = $parent;
	
	my $l = 0;
	my $t = 0;
	
	my $f = $args[0];
	my $w = $f->right - $f->left;
	my $h = $f->bottom - $f->top;
	
	if ($vertical_scroll) {
		$w -= B_V_SCROLL_BAR_WIDTH;
	}
	if ($horizontal_scroll) {
		$h -= B_H_SCROLL_BAR_HEIGHT;
	}
	
	$self->{personview} = new People::PersonView(
		$node,
		new Haiku::Rect($l,$t,$l+$w,$t+$h),
		"SearchField",	# name
		B_FOLLOW_ALL,	# resizing
		0,	# flags
	);
	
	$self->{scrollview} = new Haiku::ScrollView(
		"ScrollView",	# name
		$self->{personview},	# target
		B_FOLLOW_ALL,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
		$horizontal_scroll,	# horizontal
		$vertical_scroll,	# vertical
	);
	
	$self->AddChild($self->{scrollview}, 0);
	
	return $self;
}

sub MessageReceived {
	my ($self, $message) = @_;
	
	my $what = $message->what;
	
	if ($what == DO_SAVE) {
		return;
	}
	if ($what == DO_REVERT) {
		return;
	}
	
	$self->SUPER::MessageReceived($message);
}

sub QuitRequested {
	my ($self) = @_;
	$self->{parent}->remove_window($self);
	return 1;
}

1;

