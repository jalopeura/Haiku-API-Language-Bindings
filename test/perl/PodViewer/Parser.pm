package PodView::Parser;
use Pod::Parser;
use strict;
our @ISA = qw(Pod::Parser);

#
# lifted from HTML::Entities
#

our %entity2char = (
 # Some normal chars that have special meaning in SGML context
 amp    => '&',  # ampersand 
'gt'    => '>',  # greater than
'lt'    => '<',  # less than
 quot   => '"',  # double quote
 apos   => "'",  # single quote

 # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
 AElig	=> chr(198),  # capital AE diphthong (ligature)
 Aacute	=> chr(193),  # capital A, acute accent
 Acirc	=> chr(194),  # capital A, circumflex accent
 Agrave	=> chr(192),  # capital A, grave accent
 Aring	=> chr(197),  # capital A, ring
 Atilde	=> chr(195),  # capital A, tilde
 Auml	=> chr(196),  # capital A, dieresis or umlaut mark
 Ccedil	=> chr(199),  # capital C, cedilla
 ETH	=> chr(208),  # capital Eth, Icelandic
 Eacute	=> chr(201),  # capital E, acute accent
 Ecirc	=> chr(202),  # capital E, circumflex accent
 Egrave	=> chr(200),  # capital E, grave accent
 Euml	=> chr(203),  # capital E, dieresis or umlaut mark
 Iacute	=> chr(205),  # capital I, acute accent
 Icirc	=> chr(206),  # capital I, circumflex accent
 Igrave	=> chr(204),  # capital I, grave accent
 Iuml	=> chr(207),  # capital I, dieresis or umlaut mark
 Ntilde	=> chr(209),  # capital N, tilde
 Oacute	=> chr(211),  # capital O, acute accent
 Ocirc	=> chr(212),  # capital O, circumflex accent
 Ograve	=> chr(210),  # capital O, grave accent
 Oslash	=> chr(216),  # capital O, slash
 Otilde	=> chr(213),  # capital O, tilde
 Ouml	=> chr(214),  # capital O, dieresis or umlaut mark
 THORN	=> chr(222),  # capital THORN, Icelandic
 Uacute	=> chr(218),  # capital U, acute accent
 Ucirc	=> chr(219),  # capital U, circumflex accent
 Ugrave	=> chr(217),  # capital U, grave accent
 Uuml	=> chr(220),  # capital U, dieresis or umlaut mark
 Yacute	=> chr(221),  # capital Y, acute accent
 aacute	=> chr(225),  # small a, acute accent
 acirc	=> chr(226),  # small a, circumflex accent
 aelig	=> chr(230),  # small ae diphthong (ligature)
 agrave	=> chr(224),  # small a, grave accent
 aring	=> chr(229),  # small a, ring
 atilde	=> chr(227),  # small a, tilde
 auml	=> chr(228),  # small a, dieresis or umlaut mark
 ccedil	=> chr(231),  # small c, cedilla
 eacute	=> chr(233),  # small e, acute accent
 ecirc	=> chr(234),  # small e, circumflex accent
 egrave	=> chr(232),  # small e, grave accent
 eth	=> chr(240),  # small eth, Icelandic
 euml	=> chr(235),  # small e, dieresis or umlaut mark
 iacute	=> chr(237),  # small i, acute accent
 icirc	=> chr(238),  # small i, circumflex accent
 igrave	=> chr(236),  # small i, grave accent
 iuml	=> chr(239),  # small i, dieresis or umlaut mark
 ntilde	=> chr(241),  # small n, tilde
 oacute	=> chr(243),  # small o, acute accent
 ocirc	=> chr(244),  # small o, circumflex accent
 ograve	=> chr(242),  # small o, grave accent
 oslash	=> chr(248),  # small o, slash
 otilde	=> chr(245),  # small o, tilde
 ouml	=> chr(246),  # small o, dieresis or umlaut mark
 szlig	=> chr(223),  # small sharp s, German (sz ligature)
 thorn	=> chr(254),  # small thorn, Icelandic
 uacute	=> chr(250),  # small u, acute accent
 ucirc	=> chr(251),  # small u, circumflex accent
 ugrave	=> chr(249),  # small u, grave accent
 uuml	=> chr(252),  # small u, dieresis or umlaut mark
 yacute	=> chr(253),  # small y, acute accent
 yuml	=> chr(255),  # small y, dieresis or umlaut mark

 # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
 copy   => chr(169),  # copyright sign
 reg    => chr(174),  # registered sign
 nbsp   => chr(160),  # non breaking space

 # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
 iexcl  => chr(161),
 cent   => chr(162),
 pound  => chr(163),
 curren => chr(164),
 yen    => chr(165),
 brvbar => chr(166),
 sect   => chr(167),
 uml    => chr(168),
 ordf   => chr(170),
 laquo  => chr(171),
'not'   => chr(172),    # not is a keyword in perl
 shy    => chr(173),
 macr   => chr(175),
 deg    => chr(176),
 plusmn => chr(177),
 sup1   => chr(185),
 sup2   => chr(178),
 sup3   => chr(179),
 acute  => chr(180),
 micro  => chr(181),
 para   => chr(182),
 middot => chr(183),
 cedil  => chr(184),
 ordm   => chr(186),
 raquo  => chr(187),
 frac14 => chr(188),
 frac12 => chr(189),
 frac34 => chr(190),
 iquest => chr(191),
'times' => chr(215),    # times is a keyword in perl
 divide => chr(247),

 ( $] > 5.007 ? (
  'OElig'     => chr(338),
  'oelig'     => chr(339),
  'Scaron'    => chr(352),
  'scaron'    => chr(353),
  'Yuml'      => chr(376),
  'fnof'      => chr(402),
  'circ'      => chr(710),
  'tilde'     => chr(732),
  'Alpha'     => chr(913),
  'Beta'      => chr(914),
  'Gamma'     => chr(915),
  'Delta'     => chr(916),
  'Epsilon'   => chr(917),
  'Zeta'      => chr(918),
  'Eta'       => chr(919),
  'Theta'     => chr(920),
  'Iota'      => chr(921),
  'Kappa'     => chr(922),
  'Lambda'    => chr(923),
  'Mu'        => chr(924),
  'Nu'        => chr(925),
  'Xi'        => chr(926),
  'Omicron'   => chr(927),
  'Pi'        => chr(928),
  'Rho'       => chr(929),
  'Sigma'     => chr(931),
  'Tau'       => chr(932),
  'Upsilon'   => chr(933),
  'Phi'       => chr(934),
  'Chi'       => chr(935),
  'Psi'       => chr(936),
  'Omega'     => chr(937),
  'alpha'     => chr(945),
  'beta'      => chr(946),
  'gamma'     => chr(947),
  'delta'     => chr(948),
  'epsilon'   => chr(949),
  'zeta'      => chr(950),
  'eta'       => chr(951),
  'theta'     => chr(952),
  'iota'      => chr(953),
  'kappa'     => chr(954),
  'lambda'    => chr(955),
  'mu'        => chr(956),
  'nu'        => chr(957),
  'xi'        => chr(958),
  'omicron'   => chr(959),
  'pi'        => chr(960),
  'rho'       => chr(961),
  'sigmaf'    => chr(962),
  'sigma'     => chr(963),
  'tau'       => chr(964),
  'upsilon'   => chr(965),
  'phi'       => chr(966),
  'chi'       => chr(967),
  'psi'       => chr(968),
  'omega'     => chr(969),
  'thetasym'  => chr(977),
  'upsih'     => chr(978),
  'piv'       => chr(982),
  'ensp'      => chr(8194),
  'emsp'      => chr(8195),
  'thinsp'    => chr(8201),
  'zwnj'      => chr(8204),
  'zwj'       => chr(8205),
  'lrm'       => chr(8206),
  'rlm'       => chr(8207),
  'ndash'     => chr(8211),
  'mdash'     => chr(8212),
  'lsquo'     => chr(8216),
  'rsquo'     => chr(8217),
  'sbquo'     => chr(8218),
  'ldquo'     => chr(8220),
  'rdquo'     => chr(8221),
  'bdquo'     => chr(8222),
  'dagger'    => chr(8224),
  'Dagger'    => chr(8225),
  'bull'      => chr(8226),
  'hellip'    => chr(8230),
  'permil'    => chr(8240),
  'prime'     => chr(8242),
  'Prime'     => chr(8243),
  'lsaquo'    => chr(8249),
  'rsaquo'    => chr(8250),
  'oline'     => chr(8254),
  'frasl'     => chr(8260),
  'euro'      => chr(8364),
  'image'     => chr(8465),
  'weierp'    => chr(8472),
  'real'      => chr(8476),
  'trade'     => chr(8482),
  'alefsym'   => chr(8501),
  'larr'      => chr(8592),
  'uarr'      => chr(8593),
  'rarr'      => chr(8594),
  'darr'      => chr(8595),
  'harr'      => chr(8596),
  'crarr'     => chr(8629),
  'lArr'      => chr(8656),
  'uArr'      => chr(8657),
  'rArr'      => chr(8658),
  'dArr'      => chr(8659),
  'hArr'      => chr(8660),
  'forall'    => chr(8704),
  'part'      => chr(8706),
  'exist'     => chr(8707),
  'empty'     => chr(8709),
  'nabla'     => chr(8711),
  'isin'      => chr(8712),
  'notin'     => chr(8713),
  'ni'        => chr(8715),
  'prod'      => chr(8719),
  'sum'       => chr(8721),
  'minus'     => chr(8722),
  'lowast'    => chr(8727),
  'radic'     => chr(8730),
  'prop'      => chr(8733),
  'infin'     => chr(8734),
  'ang'       => chr(8736),
  'and'       => chr(8743),
  'or'        => chr(8744),
  'cap'       => chr(8745),
  'cup'       => chr(8746),
  'int'       => chr(8747),
  'there4'    => chr(8756),
  'sim'       => chr(8764),
  'cong'      => chr(8773),
  'asymp'     => chr(8776),
  'ne'        => chr(8800),
  'equiv'     => chr(8801),
  'le'        => chr(8804),
  'ge'        => chr(8805),
  'sub'       => chr(8834),
  'sup'       => chr(8835),
  'nsub'      => chr(8836),
  'sube'      => chr(8838),
  'supe'      => chr(8839),
  'oplus'     => chr(8853),
  'otimes'    => chr(8855),
  'perp'      => chr(8869),
  'sdot'      => chr(8901),
  'lceil'     => chr(8968),
  'rceil'     => chr(8969),
  'lfloor'    => chr(8970),
  'rfloor'    => chr(8971),
  'lang'      => chr(9001),
  'rang'      => chr(9002),
  'loz'       => chr(9674),
  'spades'    => chr(9824),
  'clubs'     => chr(9827),
  'hearts'    => chr(9829),
  'diams'     => chr(9830),
 ) : ())
);

=pod

If we have a font stack and a color stack, we can SetFontAndColor

We need to see if we leave the insertion point at the end of the text if
SetFontAndColor will apply to the next text inserted

=cut

=pod

my %formats = (
	default => {
		font => Haiku::Font::be_plain_font(),	# x = {be_plain_font, be_fixed_font, be_bold_font}
		face => B_NORMAL_FACE,	# x = {ITALIC, UNDERSCORE, NEGATIVE, OUTLINED, STRIKEOUT, BOLD, REGULAR}
		size => 10,
		color => [255,255,255],
	},
	head1 => {
		font => Haiku::Font::be_bold_font(),	# x = {be_plain_font, be_fixed_font, be_bold_font}
		face => B_BOLD_FACE,	# x = {ITALIC, UNDERSCORE, NEGATIVE, OUTLINED, STRIKEOUT, BOLD, REGULAR}
		size => 20,
		color => [255,255,255],
	},
	head2 => {
		font => Haiku::Font::be_bold_font(),	# x = {be_plain_font, be_fixed_font, be_bold_font}
		face => B_BOLD_FACE,	# x = {ITALIC, UNDERSCORE, NEGATIVE, OUTLINED, STRIKEOUT, BOLD, REGULAR}
		size => 10,
		color => [255,255,255],
	},
);

=cut

=pod

$self->{text_view}->Insert("text", $format);

for my $k (keys %format) {
	my $fmt = $format{$k};
	
	my $font = new Haiku::Font($fmt->{font});
	$font->SetFace($fmt->{face});
	
	my $text_run = new Haiku::text_run;
	$text_run->offset = 0;
	$text_run->font = $font;
	$text_run->color = Haiku::InterfaceKit::make_color(@{ $fmt->{color} });
	
	my $text_run_array = new Haiku::text_run_array;
	$text_run_array->runs = [ $text_run ];
	
	$format{$k} = $text_run_array;
}

=cut

sub new {
	my ($class, $text_view) = @_;
	my $self = $class->SUPER::new;
	
	$self->{viewer} = $text_view;
	
	return $self;
}

# commands are the =XXX POD directives; the text can have formatting codes
sub command {
	my ($self, $cmd, $text, $line_num, $pod_para) = @_;
	
	#
	# here handle starting a new paragraph
	#
#print "START COMMAND ($cmd):\n\n";
	
	$text=~s/\s+/ /g; $text=~s/^ //; $text=~s/ $//;
	my $parse_tree = $self->parse_text($text, $line_num);
	$self->display_tree($parse_tree);	# can add other args (like text_run) later
#print "END COMMAND ($cmd):\n\n";
}

# verbatim paragraphs should not be parsed for formatting codes; they are usually code samples
sub verbatim {
	my ($self, $text, $line_num, $pod_para) = @_;
	
	#
	# here set up the stuff for verbatims
	#
	
	$self->{viewer}->SetMonospace(1);
	$self->{viewer}->Display($text);
	$self->{viewer}->SetMonospace(0);
	
	$self->{viewer}->Display("\n\n");	# end of a paragraph
}

# ordinary block of text; it can have formatting codes
sub textblock {
	my ($self, $text, $line_num, $pod_para) = @_;
	
	$text=~s/\s+/ /g; $text=~s/^ //; $text=~s/ $//;
	my $parse_tree = $self->parse_text($text, $line_num);
	$self->display_tree($parse_tree);	# can add other args (like text_run) later
	
	$self->{viewer}->Display("\n\n");	# end of a paragraph
}

sub display_tree {
	my ($self, $parse_tree) = @_;
	
	for my $child ($parse_tree->children) {
		if (ref $child) {
			$self->display_sequence($child);
		}
		else {
			$self->{viewer}->Display($child);
		}
	}
}

sub display_sequence {
	my ($self, $sequence) = @_;
	
	my $cmd = $sequence->cmd_name;
	my $parse_tree = $sequence->parse_tree;
	
	# Z<> (zero code; for breaking up sequences like E< as EZ<>< 
	# (so they don't render as sequences)
	if ($cmd eq 'Z') {
		return;	# do nothing
	}
	
	# E<escape>
	#   Supported escapes:
	#     lt (<), gt (>), verbar (|), sol (/)
	#     htmlname (html escape) USE: @decoded_strings = HTML::Entities->decode_entities(@encoded_strings);
	#     number (character code; dec, 0oct, 0xhex)
	if ($cmd eq 'E') {
		my $e = $parse_tree->raw_text;
		my $u;
		if ($e eq 'sol') {
			$u = '/';
		}
		elsif ($e eq 'verbar') {
			$u = '|';
		}
		elsif ($e=~/^0x[\da-fA-F]+$/) {
			$u = chr hex $e;
		}
		elsif ($e=~/^0\d+$/) {
			$u = chr oct $e;
		}
		elsif ($e=~/^\d+$/) {
			$u = chr $e;
		}
		else {
			$u = $entity2char{$e};
		}
		$u ||= $e;	# oops, sequence not recognized
		$self->{viewer}->Display($u);
		return;
	}
	
	# X<topic> (for creating indexes; render as an empty string)
	if ($cmd eq 'X') {
		$self->{viewer}->SetIndexMark($text);
		#
		# here set up indexing if we want to support that
		#
		return;
	}
	
	# S<text> (do not wrap)
	if ($cmd eq 'S') {
		$self->{viewer}->SetNowrap(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetNowrap(0);
		return;
	}
	
	# B<text> (bold)
	if ($cmd eq 'B') {
		$self->{viewer}->SetBold(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetBold(0);
		return;
	}
	
	# I<text> (italic)
	if ($cmd eq 'I') {
		$self->{viewer}->SetItalic(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetItalic(0);
		return;
	}
	
	# C<text> (code)
	if ($cmd eq 'I') {
		$self->{viewer}->SetMonospace(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetMonospace(0);
		return;
	}
	
	# F<text> (filename)
	if ($cmd eq 'F') {
		$self->{viewer}->PushColor(0,255,0);
		$self->{viewer}->SetBold(1);
		$self->{viewer}->SetMonospace(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetMonospace(0);
		$self->{viewer}->SetBold(0);
		$self->{viewer}->PopColor;
		return;
	}
	
	# L<text|name> (link to pod page)
	# L<text|name/"sec"> OR L<text|name/sec> (link to section)
	# L<text|/"sec"> OR L<text|/sec> OR L<text|"sec"> (link to section in this page)
	#   NOTE: text| is optional; without it, default to contents
	# L<scheme:> (link to http, ftp, whatever; no text| option)
	if ($cmd eq 'L') {
		my $raw = $parse_tree->raw_text;
		my $text;
		if ($raw=~s/^(.+?)\|//) {
			$text = $1;
		}
		else {
			my ($page, $section) = split m:/:, $raw;
			if ($section) {
				$page ||= 'this page';
				$text = "$section in $page";
			}
			else {
				$text = $raw;
				$text=~s/^"//;
				$text=~s/"$//;
			}
		}
		
		$self->{viewer}->PushColor(0,0,255);
		$self->{viewer}->DisplayLink($text, $link);
		$self->{viewer}->SetBold(0);
	}
}

sub Xinterior_sequence {
	my ($self, $seq_cmd, $seq_arg, $pod_seq) = @_;
print <<INFO;
SEQUENCE
CMD: $seq_cmd
ARG: $seq_arg

INFO
	return "SEQ[$seq_cmd/$seq_arg]";
}

sub Xinitialize {
	print join("\n", 'initialize', @_),"\n\n";
	my $self = shift;
	$self->SUPER::initialize(@_);
}

sub Xbegin_pod {
	print join("\n", 'begin_pod', @_),"\n\n";
	my ($self) = @_;
}

sub Xend_pod {
	print join("\n", 'end_pod', @_),"\n\n";
	my ($self) = @_;
}

sub Xpreprocess_paragraph {
	print join("\n", 'preprocess_paragraph', @_),"\n\n";
	my ($self, $text, $line_number) = @_;
}

sub Xpreprocess_line {
	print join("\n", 'preprocess_line', @_),"\n\n";
	my ($self, $text, $line_number) = @_;
}

sub Xbegin_input {
	print join("\n", 'begin_input', @_),"\n\n";
}

sub Xend_input {
	print join("\n", 'end_input', @_),"\n\n";
}

1;
