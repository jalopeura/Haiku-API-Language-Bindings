package People::PersonView;
use Haiku::SupportKit;
use Haiku::InterfaceKit;
use Haiku::View qw(B_FOLLOW_ALL B_FOLLOW_TOP B_FOLLOW_LEFT_RIGHT B_WILL_DRAW B_NAVIGABLE);
use Haiku::ScrollBar qw(B_V_SCROLL_BAR_WIDTH B_H_SCROLL_BAR_HEIGHT);
use Haiku::TypeConstants qw(:types);
use strict;
our @ISA = qw(Haiku::View);

use constant DO_SAVE       => 0xffff0001;
use constant DO_REVERT     => 0xffff0001;

my $buffer_size = 5;
my $control_height = 20;
my $label_width = 100;

sub new {
	my ($class, $file, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	$self->{file} = $file;
	$self->{node} = new Haiku::Node($self->{file});
	$self->{controls} = {};
	
	$self->add_attr_views($args[0]);
	$self->populate_attr_views;
	
	return $self;
}

sub add_attr_views {
	my ($self, $frame) = @_;
	
	my $l = 0;
	my $t = 0;
	
	my $w = $frame->right - $frame->left;
	my $h = $frame->bottom - $frame->top;
	
	$self->{node}->RewindAttrs;
	while (my $attr_name = $self->{node}->GetNextAttrName) {
		next unless $attr_name=~/^META:/;
		my $attr_info = $self->{node}->GetAttrInfo($attr_name) or
			warn "Unable to retrieve info for $attr_name: " .
			find_haiku_error($Haiku::StorageKit::Error) and
			next;
		$self->create_attr_view(
			$attr_name, $attr_info->type,
			$buffer_size, $t, $w-2*$buffer_size, $control_height,
		);
		$t += $control_height + $buffer_size;
	}
}

sub create_attr_view {
	my ($self, $name, $type, $l, $t, $w, $h) = @_;
	
	(my $control_name = $name)=~s/^META://;
	
	if ($type == B_STRING_TYPE) {
		$self->{controls}{$name} = new Haiku::TextControl(
			new Haiku::Rect($l, $t, $l+$w, $t+$h),
			$control_name,
			$control_name,
			"",
			new Haiku::Message(0),
			B_FOLLOW_LEFT_RIGHT | B_FOLLOW_TOP,
			B_WILL_DRAW | B_NAVIGABLE,
		);
		$self->{controls}{$name}->SetDivider($label_width+$buffer_size);
		$self->AddChild($self->{controls}{$name});
		return;
	}
	
	warn("Unsupported attribute type: $type ($name)");
}

sub populate_attr_views {
	my ($self) = @_;
	
	$self->{current} = {};
	
	$self->{node}->RewindAttrs;
	while (my $attr_name = $self->{node}->GetNextAttrName) {
		next unless $attr_name=~/^META:/;
		my $attr_info = $self->{node}->GetAttrInfo($attr_name) or
			warn "Unable to retrieve info for $attr_name: " .
			find_haiku_error($Haiku::StorageKit::Error) and
			next;
		my ($bytes, $value) = $self->{node}->ReadAttr(
			$attr_name,
			$attr_info->type,
			0,	# offset (unused?)
			$attr_info->size,
		);
		my $type = $attr_info->type;
		
		if ($type == B_STRING_TYPE) {
			$self->{current}{$attr_name} = $value;
			$self->{controls}{$attr_name}->SetText($value);
			next;
		}
		
		warn("Unsupported attribute type: $type ($attr_name)");
	}
}

sub save_data {
	my ($self) = @_;
	
	my $node = new Haiku::Node($self->{file});
	
	warn "Saving not yet implemented";
}

sub find_haiku_error {
	my ($errval) = @_;
	for my $errname (@Haiku::Errors::EXPORT_OK) {
		my $err = eval "Haiku::Errors::$errname";
		next unless $err == $errval;
		return $err;
	}
}


1;

