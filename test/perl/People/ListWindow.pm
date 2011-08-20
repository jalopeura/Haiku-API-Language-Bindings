package People::ListWindow;
use Haiku::SupportKit;
use Haiku::InterfaceKit;
use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use Haiku::View qw(B_FOLLOW_ALL B_FOLLOW_TOP B_FOLLOW_LEFT_RIGHT B_WILL_DRAW B_NAVIGABLE);
use Haiku::ListView qw(B_SINGLE_SELECTION_LIST);
use Haiku::ScrollBar qw(B_V_SCROLL_BAR_WIDTH B_H_SCROLL_BAR_HEIGHT);
use Haiku::TypeConstants qw(:types);
use People::PersonWindow;
use strict;
our @ISA = qw(Haiku::CustomWindow);

my $people_count;

use constant ITEM_SELECTED => 0xffff0001;

my $horizontal_scroll = 1;
my $vertical_scroll = 1;

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	$self->{item_map} = {};
	$self->{person_windows} = [];
	
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
	
	$self->{listview} = new Haiku::ListView(
		new Haiku::Rect($l,$t,$l+$w,$t+$h),	# frame
		"People::ListView",	# name
		B_SINGLE_SELECTION_LIST,	# type
		B_FOLLOW_ALL,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
	);
	
	$self->{scrollview} = new Haiku::ScrollView(
		"ScrollView",	# name
		$self->{listview},	# target
		B_FOLLOW_ALL,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
		$horizontal_scroll,	# horizontal
		$vertical_scroll,	# vertical
	);
	
	$self->AddChild($self->{scrollview}, 0);
	
	$self->{invocation_message} = new Haiku::Message(ITEM_SELECTED);
	$self->{listview}->SetInvocationMessage($self->{invocation_message});
	
	return $self;
}

sub MessageReceived {
	my ($self, $msg) = @_;
	
	my $what = $msg->what;
	
	if ($what == ITEM_SELECTED) {
		my $selected = $msg->FindInt32('index');
		my $item = $self->{listview}->ItemAt($selected);
		bless $item, 'Haiku::StringItem';	# bless into proper class
		my $key = $item->Text;
		my $file = $self->{item_map}{$key};
		
		# where should we save these?
		my $win = new People::PersonWindow(
			$self,
			$file,
			new Haiku::Rect(350,50,700,350),	# frame
			$key,	# title
			B_TITLED_WINDOW,	# type
			0,	# flags
		);
		push @{ $self->{personwindows} }, $win;
		$win->Show;
		return;
	}
	
	$self->SUPER::MessageReceived($msg);
}

sub QuitRequested {
	my ($self) = @_;
	if ($self->{personwindows}) {
		while (@{ $self->{personwindows} }) {
			my $win = shift @{ $self->{personwindows} };
			$win->Lock;
			$win->Quit;
		}
	}
	return 1;
}

sub remove_window {
	my ($self, $win) = @_;
	
	my $i;
	for my $w (@{ $self->{personwindows} }) {
		last if $w == $win;
		$i++;
	}
	splice @{ $self->{personwindows} }, $i, 1;
}

sub add_person {
	# currently limited due to an unresolved refcount issue
#	return if $people_count++ >= 40;
	my ($self, $file) = @_;
	my $maxlen = 100;	# maximum number of bytes to read
	my $i = 0;
	my $node = new Haiku::Node($file);
	my ($bytes, $name) = $node->ReadAttr(
		'META:name',
		B_STRING_TYPE,	# type (unused?)
		0,	# offset (unused?)
		$maxlen,	# maximum number of bytes to read
	);
	# negative bytes means an error code
	if ($bytes < 0) {
		$name = 'UNNAMED' .  ++$i;
	}
	else {
		$bytes--;	# number returned includes trailing null
		substr($name, $bytes, $maxlen-$bytes, '');
	}
	my $item = new Haiku::StringItem($name);
	$self->{listview}->AddItem($item);
	$self->{item_map}{$name} = $file;
	undef $node;
	undef $node;
}

sub remove_person {
	my ($self, $file) = @_;
	print "Removing $file\n";
}

1;

