package PodViewer::PodView;
use strict;
our @ISA = qw(Haiku::TextView);

my $NonBreakingSpace = pack('U', 0xa0);
my $ItemMarker = pack('U', 8226);

use constant DEFAULT_CURSOR => Haiku::Cursor->newFromID(Haiku::Cursor::B_CURSOR_ID_SYSTEM_DEFAULT);
use constant TEXT_CURSOR    => Haiku::Cursor->newFromID(Haiku::Cursor::B_CURSOR_ID_I_BEAM);
use constant LINK_CURSOR    => Haiku::Cursor->newFromID(Haiku::Cursor::B_CURSOR_ID_FOLLOW_LINK);

sub make_color {
	my $c = new Haiku::rgb_color;
	$c->red   = $_[0];
	$c->green = $_[1];
	$c->blue  = $_[2];
	return $c;
}

use constant DEFAULT_COLOR  => make_color(0,0,0);
use constant LINK_COLOR     => make_color(0,0,255);
use constant FILENAME_COLOR => make_color(0,255,0);
use constant UNKNOWN_COLOR  => make_color(255,0,0);

use constant DEFAULT_SIZE  => 12;
use constant HEAD1_SIZE    => 20;
use constant HEAD2_SIZE    => 18;
use constant HEAD3_SIZE    => 16;
use constant HEAD4_SIZE    => 14;

use constant ITEM_LEVELS => [
	pack('U', 8226),
	pack('U', 173),
	'*',
];

use constant DEFAULT_FORMAT => 'pod';

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new(@_);
	
	$self->SetStylable(1);
	$self->MakeEditable(0);
	
	$self->{_color} = DEFAULT_COLOR;
	$self->{_color_stack} = [ $self->{_color} ];
	
	$self->{_size} = DEFAULT_SIZE;
	$self->{_size_stack} = [ $self->{_size} ];
	
	$self->{_format} = DEFAULT_FORMAT;
	$self->{_format_stack} = [ $self->{_format} ];
	
	$self->build_font;
	
	return $self;
}

sub build_font {
	my ($self) = @_;

	$self->{_monospace_on} = 0;
	$self->{_bold_on} = 0;
	$self->{_italic_on} = 0;
	
	my ($base_font, $face);
	if ($self->{_monospace}) {
		$self->{_monospace_on} = 1;
		$base_font = Haiku::Font::be_fixed_font;
		if ($self->{_bold}) {
			$self->{_bold_on} = 1;
			$face = Haiku::Font::B_BOLD_FACE;
		}
	}
	elsif ($self->{_bold}) {
		$self->{_bold_on} = 1;
		$base_font = Haiku::Font::be_bold_font;
		$face = Haiku::Font::B_BOLD_FACE;
	}
	else {
		$base_font = Haiku::Font::be_plain_font;
	}
	
	if ($self->{_italic}) {
		$self->{_italic_on} = 1;
		$face |= Haiku::Font::B_ITALIC_FACE
	}
	
	my $font = Haiku::Font->newFromFont($base_font);
	$font->SetFace($face);
	$font->SetSize($self->{_size_stack}[-1]);
	
	$self->{_font} = $font;
	
	return $font;
}

sub Reset {
	my ($self) = @_;
	
	$self->{_bold} = 0;
	$self->{_italic} = 0;
	$self->{_monospace} = 0;
	
	$self->{_color} = DEFAULT_COLOR;
	$self->{_color_stack} = [ $self->{_color} ];
	
	$self->{_size} = DEFAULT_SIZE;
	$self->{_size_stack} = [ $self->{_size} ];
	
	$self->{_format} = DEFAULT_FORMAT;
	$self->{_format_stack} = [ $self->{_format} ];
	
	$self->SetTextWithLength('', 0);
	
	$self->build_font;
	
	$self->SetFontAndColor(
		$self->{_font},
		Haiku::View::B_FONT_ALL,
		$self->{_color},
	);
}

sub StartParagraph {
	my ($self) = @_;
	
	if ($self->{_in_item}) {
		$self->{_in_item} = 0;
		return;
	}
	
	my $pfx = "\t" x $self->{_indent};
# turned off because some POD files mark their own items
#	if ($self->{_item}) {
#		my $i = ($self->{_item} - 1) % scalar @{ &ITEM_LEVELS } ;
#		$pfx .= ITEM_LEVELS->[$i] . ' ';
#	}
	$self->Display($pfx) if $pfx;
}

sub EndParagraph {
	my ($self) = @_;
	
	if ($self->{_in_item}) {
		return;
	}
	
	$self->Display("\n\n");
}

sub Display {
	my ($self, $text) = @_;
	
	if ($self->{_item}) {
		# if item text is '*' or a number followed by a period
		# the next paragraph will be part of the the item
		$text=~s/^\*\s*/$ItemMarker/ and $self->{_in_item} = 1;
		$text=~s/^(\d+\.)\s*/$1/ and $self->{_in_item} = 1;
		
		if ($self->{_in_item}) {
			$self->{_bold}++;
			$self->{_font_changed}++;
		}
	}
	
	# formats not currently supported
	return unless $self->{_format_stack}[-1] eq DEFAULT_FORMAT;
	
	if ($self->{_nowrap}) {
		$text=~s/ /$NonBreakingSpace/g;
	}
		
#	my $tr = new Haiku::text_run;
#	$tr->offset = 0;
#	$tr->font = $self->{_font};
#	$tr->color = $self->{_color}[-1];
	
#	my $tra = new Haiku::text_run_array;
#	$tra->runs = [ $tr ];

#	$self->Insert($text, $tra);
	
	my $really_changed;
	
	if ($self->{_font_changed}) {
		if (
			($self->{_monospace_on} and not $self->{_monospace}) or
			($self->{_monospace} and not $self->{_monospace_on}) or
			($self->{_bold_on} and not $self->{_bold}) or
			($self->{_bold} and not $self->{_bold_on}) or
			($self->{_italic_on} and not $self->{_italic}) or
			($self->{_italic} and not $self->{_italic_on}) or
			($self->{_italic} and not $self->{_italic_on}) or
			($self->{_size} != $self->{_size_stack}[-1])
			) {
			$self->build_font;
			$really_changed = 1;
		}
		$self->{_font_changed} = 0;
	}
	
	if ($self->{_color_changed}) {
		if ($self->{_color} != $self->{_color_stack}[-1]) {
			$self->{_color} = $self->{_color_stack}[-1];
			$really_changed = 1;
		}
		$self->{_color_changed} = 0;
	}
	
	if ($really_changed) {
		$self->SetFontAndColor(
			$self->{_font},
			Haiku::View::B_FONT_ALL,
			$self->{_color},
		);
	}

	$self->Insert($text);
	
	if ($self->{_in_item}) {
		$self->Insert(' ');
		$self->{_bold}--;
		$self->{_font_changed}++;
		return;
	}
}

sub SetLinkAnchor {
	my ($self, $text) = @_;
	$self->{_link_anchors}{$text} = $self->TextLength;
}

sub DisplayLink {
	my ($self, $text, $target) = @_;
	
	my $start = $self->TextLength;
	$self->Display($text);
	my $end = $self->TextLength;
	
	push @{ $self->{_links} }, [ $start, $end ];
}

sub SetIndexMark {
	my ($self, $text) = @_;
	#
	# ignore it for now
	#
}

#
# mode setters
#

sub SetEncoding {
	my ($self, $encoding) = @_;
	#
	# currently ignored
	#
}

sub SetHeadMode {
	my ($self, $state, $size) = @_;
	if ($state) {
		push @{ $self->{_size_stack} }, $size;
		$self->{_bold}++;
	}
	else {
		pop @{ $self->{_size_stack} };
		$self->{_bold}--;
	}
	$self->{_font_changed}++;
}

sub SetHead1Mode {
	my ($self, $state) = @_;
	$self->SetHeadMode($state, HEAD1_SIZE);
}

sub SetHead2Mode {
	my ($self, $state) = @_;
	$self->SetHeadMode($state, HEAD2_SIZE);
}

sub SetHead3Mode {
	my ($self, $state) = @_;
	$self->SetHeadMode($state, HEAD3_SIZE);
}

sub SetHead4Mode {
	my ($self, $state) = @_;
	$self->SetHeadMode($state, HEAD4_SIZE);
}

sub SetIndent {
	my ($self, $state) = @_;
	$state ? $self->{_indent}++ : $self->{_indent}--;
}

sub SetItemMode {
	my ($self, $state) = @_;
	$state ? $self->{_item}++ : $self->{_item}--;
}

sub SetFormatMode {
	my ($self, $format, $state) = @_;
	if ($state) {
		push @{ $self->{_format_stack} }, $format;
	}
	else {
		pop @{ $self->{_format_stack} };
	}
}

sub SetVerbatimMode {
	my ($self, $state) = @_;
	$state ? $self->{_monospace}++ : $self->{_monospace}--;
	$self->{_font_changed}++;
}

sub SetSMode {
	my ($self, $state) = @_;
	$state ? $self->{_nowrap}++ : $self->{_nowrap}--;
}

sub SetBMode {
	my ($self, $state) = @_;
	$state ? $self->{_bold}++ : $self->{_bold}--;
	$self->{_font_changed}++;
}

sub SetIMode {
	my ($self, $state) = @_;
	$state ? $self->{_italic}++ : $self->{_italic}--;
	$self->{_font_changed}++;
}

sub SetCMode {
	my ($self, $state) = @_;
	$state ? $self->{_monospace}++ : $self->{_monospace}--;
	$self->{_font_changed}++;
}

sub SetFMode {
	my ($self, $state) = @_;
	if ($state) {
		push @{ $self->{_color_stack} }, FILENAME_COLOR;
		$self->{_monospace}++;
		$self->{_bold}++;
	}
	else {
		pop @{ $self->{_color_stack} };
		$self->{_monospace}--;
		$self->{_bold}--;
	}
	$self->{_color_changed}++;
	$self->{_font_changed}++;
}

sub SetLMode {
	my ($self, $state) = @_;
	if ($state) {
		push @{ $self->{_color_stack} }, LINK_COLOR;
		$self->{_monospace}++;
		$self->{_bold}++;
	}
	else {
		pop @{ $self->{_color_stack} };
		$self->{_monospace}--;
		$self->{_bold}--;
	}
	$self->{_color_changed}++;
	$self->{_font_changed}++;
}

sub SetUnknownMode {
	my ($self, $state) = @_;
	if ($state) {
		push @{ $self->{_color_stack} }, UNKNOWN_COLOR;
		$self->{_monospace}++;
		$self->{_bold}++;
	}
	else {
		pop @{ $self->{_color_stack} };
		$self->{_monospace}--;
		$self->{_bold}--;
	}
	$self->{_color_changed}++;
	$self->{_font_changed}++;
}

1;
