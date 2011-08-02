package PodViewer::PodView;
use strict;
our @ISA = qw(Haiku::TextView);

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new(@_);
	
	$self->{color} = [];
	$self->PushColor(0,0,0);
	
	return $self;
}

sub build_font {
	my ($self) = @_;
	
	my ($base_font, $face);
	if ($self->{monospace}) {
		$base_font = Haiku::Font::be_fixed_font;
		if ($self->{bold}) {
			$face = Haiku::Font::B_BOLD_FACE;
		}
	}
	elsif ($self->{bold}) {
		$base_font = Haiku::Font::be_bold_font;
		$face = Haiku::Font::B_BOLD_FACE;
	}
	else {
		$base_font = Haiku::Font::be_plain_font;
	}
	
	if ($self->{italic}) {
		$face |= Haiku::Font::B_ITALIC_FACE
	}
	
	$self->{_font} = new Haiku::Font($base_font);
	$self->{_font}->SetFace($face);
}

sub Display {
	my ($self, $text) = @_;
	
	my $tr = new Haiku::text_run;
	$tr->offset = 0;
	$tr->font = $self->{_font};
	$tr->color = $self->{color}[-1];
	
	my $tra = new Haiku::text_run_array;
	$tra->runs = [ $tr ];
	
	if ($self->{nowrap}) {
		$text=~s/ /\x{a0}/g;
	}

#print "Inserting $text\n";
	$self->Insert($text, $tra);
#	$self->Invalidate;
}

sub PushColor {
	my ($self, $r, $g, $b) = @_;
	my $color = new Haiku::rgb_color;
	$color->red = $r;
	$color->green = $g;
	$color->blue = $b;
	push @{ $self->{colors} }, $color;
}

sub PopColor {
	my ($self) = @_;
	pop @{ $self->{colors} };
}

sub SetBold {
	my ($self, $state) = @_;
	$state ? $self->{_bold}++ : $self->{_bold}--;
	$self->build_font;
}

sub SetItalic {
	my ($self, $state) = @_;
	$state ? $self->{_italic}++ : $self->{_italic}--;
	$self->build_font;
}

sub SetMonospace {
	my ($self, $state) = @_;
	$state ? $self->{_monospace}++ : $self->{_monospace}--;
	$self->build_font;
}

sub SetNowrap {
	my ($self, $state) = @_;
	$state ? $self->{_nowrap}++ : $self->{_nowrap}--;
}

sub SetIndexMark {
	my ($self, $text) = @_;
	#
	# ignore it for now
	#
}

1;
