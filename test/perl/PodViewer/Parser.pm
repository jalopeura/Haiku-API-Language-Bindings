package PodView::Parser;
use Pod::Parser;
use strict;
our @ISA = qw(Pod::Parser);

#
# adapted from HTML::Entities
#

our %entity2char = (
 # Some normal chars that have special meaning in SGML context
 amp    => '&',  # ampersand 
'gt'    => '>',  # greater than
'lt'    => '<',  # less than
 quot   => '"',  # double quote
 apos   => "'",  # single quote

 # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
 AElig	=> pack('U', 198),  # capital AE diphthong (ligature)
 Aacute	=> pack('U', 193),  # capital A, acute accent
 Acirc	=> pack('U', 194),  # capital A, circumflex accent
 Agrave	=> pack('U', 192),  # capital A, grave accent
 Aring	=> pack('U', 197),  # capital A, ring
 Atilde	=> pack('U', 195),  # capital A, tilde
 Auml	=> pack('U', 196),  # capital A, dieresis or umlaut mark
 Ccedil	=> pack('U', 199),  # capital C, cedilla
 ETH	=> pack('U', 208),  # capital Eth, Icelandic
 Eacute	=> pack('U', 201),  # capital E, acute accent
 Ecirc	=> pack('U', 202),  # capital E, circumflex accent
 Egrave	=> pack('U', 200),  # capital E, grave accent
 Euml	=> pack('U', 203),  # capital E, dieresis or umlaut mark
 Iacute	=> pack('U', 205),  # capital I, acute accent
 Icirc	=> pack('U', 206),  # capital I, circumflex accent
 Igrave	=> pack('U', 204),  # capital I, grave accent
 Iuml	=> pack('U', 207),  # capital I, dieresis or umlaut mark
 Ntilde	=> pack('U', 209),  # capital N, tilde
 Oacute	=> pack('U', 211),  # capital O, acute accent
 Ocirc	=> pack('U', 212),  # capital O, circumflex accent
 Ograve	=> pack('U', 210),  # capital O, grave accent
 Oslash	=> pack('U', 216),  # capital O, slash
 Otilde	=> pack('U', 213),  # capital O, tilde
 Ouml	=> pack('U', 214),  # capital O, dieresis or umlaut mark
 THORN	=> pack('U', 222),  # capital THORN, Icelandic
 Uacute	=> pack('U', 218),  # capital U, acute accent
 Ucirc	=> pack('U', 219),  # capital U, circumflex accent
 Ugrave	=> pack('U', 217),  # capital U, grave accent
 Uuml	=> pack('U', 220),  # capital U, dieresis or umlaut mark
 Yacute	=> pack('U', 221),  # capital Y, acute accent
 aacute	=> pack('U', 225),  # small a, acute accent
 acirc	=> pack('U', 226),  # small a, circumflex accent
 aelig	=> pack('U', 230),  # small ae diphthong (ligature)
 agrave	=> pack('U', 224),  # small a, grave accent
 aring	=> pack('U', 229),  # small a, ring
 atilde	=> pack('U', 227),  # small a, tilde
 auml	=> pack('U', 228),  # small a, dieresis or umlaut mark
 ccedil	=> pack('U', 231),  # small c, cedilla
 eacute	=> pack('U', 233),  # small e, acute accent
 ecirc	=> pack('U', 234),  # small e, circumflex accent
 egrave	=> pack('U', 232),  # small e, grave accent
 eth	=> pack('U', 240),  # small eth, Icelandic
 euml	=> pack('U', 235),  # small e, dieresis or umlaut mark
 iacute	=> pack('U', 237),  # small i, acute accent
 icirc	=> pack('U', 238),  # small i, circumflex accent
 igrave	=> pack('U', 236),  # small i, grave accent
 iuml	=> pack('U', 239),  # small i, dieresis or umlaut mark
 ntilde	=> pack('U', 241),  # small n, tilde
 oacute	=> pack('U', 243),  # small o, acute accent
 ocirc	=> pack('U', 244),  # small o, circumflex accent
 ograve	=> pack('U', 242),  # small o, grave accent
 oslash	=> pack('U', 248),  # small o, slash
 otilde	=> pack('U', 245),  # small o, tilde
 ouml	=> pack('U', 246),  # small o, dieresis or umlaut mark
 szlig	=> pack('U', 223),  # small sharp s, German (sz ligature)
 thorn	=> pack('U', 254),  # small thorn, Icelandic
 uacute	=> pack('U', 250),  # small u, acute accent
 ucirc	=> pack('U', 251),  # small u, circumflex accent
 ugrave	=> pack('U', 249),  # small u, grave accent
 uuml	=> pack('U', 252),  # small u, dieresis or umlaut mark
 yacute	=> pack('U', 253),  # small y, acute accent
 yuml	=> pack('U', 255),  # small y, dieresis or umlaut mark

 # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
 copy   => pack('U', 169),  # copyright sign
 reg    => pack('U', 174),  # registered sign
 nbsp   => pack('U', 160),  # non breaking space

 # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
 iexcl  => pack('U', 161),
 cent   => pack('U', 162),
 pound  => pack('U', 163),
 curren => pack('U', 164),
 yen    => pack('U', 165),
 brvbar => pack('U', 166),
 sect   => pack('U', 167),
 uml    => pack('U', 168),
 ordf   => pack('U', 170),
 laquo  => pack('U', 171),
'not'   => pack('U', 172),    # not is a keyword in perl
 shy    => pack('U', 173),
 macr   => pack('U', 175),
 deg    => pack('U', 176),
 plusmn => pack('U', 177),
 sup1   => pack('U', 185),
 sup2   => pack('U', 178),
 sup3   => pack('U', 179),
 acute  => pack('U', 180),
 micro  => pack('U', 181),
 para   => pack('U', 182),
 middot => pack('U', 183),
 cedil  => pack('U', 184),
 ordm   => pack('U', 186),
 raquo  => pack('U', 187),
 frac14 => pack('U', 188),
 frac12 => pack('U', 189),
 frac34 => pack('U', 190),
 iquest => pack('U', 191),
'times' => pack('U', 215),    # times is a keyword in perl
 divide => pack('U', 247),

 ( $] > 5.007 ? (
  'OElig'     => pack('U', 338),
  'oelig'     => pack('U', 339),
  'Scaron'    => pack('U', 352),
  'scaron'    => pack('U', 353),
  'Yuml'      => pack('U', 376),
  'fnof'      => pack('U', 402),
  'circ'      => pack('U', 710),
  'tilde'     => pack('U', 732),
  'Alpha'     => pack('U', 913),
  'Beta'      => pack('U', 914),
  'Gamma'     => pack('U', 915),
  'Delta'     => pack('U', 916),
  'Epsilon'   => pack('U', 917),
  'Zeta'      => pack('U', 918),
  'Eta'       => pack('U', 919),
  'Theta'     => pack('U', 920),
  'Iota'      => pack('U', 921),
  'Kappa'     => pack('U', 922),
  'Lambda'    => pack('U', 923),
  'Mu'        => pack('U', 924),
  'Nu'        => pack('U', 925),
  'Xi'        => pack('U', 926),
  'Omicron'   => pack('U', 927),
  'Pi'        => pack('U', 928),
  'Rho'       => pack('U', 929),
  'Sigma'     => pack('U', 931),
  'Tau'       => pack('U', 932),
  'Upsilon'   => pack('U', 933),
  'Phi'       => pack('U', 934),
  'Chi'       => pack('U', 935),
  'Psi'       => pack('U', 936),
  'Omega'     => pack('U', 937),
  'alpha'     => pack('U', 945),
  'beta'      => pack('U', 946),
  'gamma'     => pack('U', 947),
  'delta'     => pack('U', 948),
  'epsilon'   => pack('U', 949),
  'zeta'      => pack('U', 950),
  'eta'       => pack('U', 951),
  'theta'     => pack('U', 952),
  'iota'      => pack('U', 953),
  'kappa'     => pack('U', 954),
  'lambda'    => pack('U', 955),
  'mu'        => pack('U', 956),
  'nu'        => pack('U', 957),
  'xi'        => pack('U', 958),
  'omicron'   => pack('U', 959),
  'pi'        => pack('U', 960),
  'rho'       => pack('U', 961),
  'sigmaf'    => pack('U', 962),
  'sigma'     => pack('U', 963),
  'tau'       => pack('U', 964),
  'upsilon'   => pack('U', 965),
  'phi'       => pack('U', 966),
  'chi'       => pack('U', 967),
  'psi'       => pack('U', 968),
  'omega'     => pack('U', 969),
  'thetasym'  => pack('U', 977),
  'upsih'     => pack('U', 978),
  'piv'       => pack('U', 982),
  'ensp'      => pack('U', 8194),
  'emsp'      => pack('U', 8195),
  'thinsp'    => pack('U', 8201),
  'zwnj'      => pack('U', 8204),
  'zwj'       => pack('U', 8205),
  'lrm'       => pack('U', 8206),
  'rlm'       => pack('U', 8207),
  'ndash'     => pack('U', 8211),
  'mdash'     => pack('U', 8212),
  'lsquo'     => pack('U', 8216),
  'rsquo'     => pack('U', 8217),
  'sbquo'     => pack('U', 8218),
  'ldquo'     => pack('U', 8220),
  'rdquo'     => pack('U', 8221),
  'bdquo'     => pack('U', 8222),
  'dagger'    => pack('U', 8224),
  'Dagger'    => pack('U', 8225),
  'bull'      => pack('U', 8226),
  'hellip'    => pack('U', 8230),
  'permil'    => pack('U', 8240),
  'prime'     => pack('U', 8242),
  'Prime'     => pack('U', 8243),
  'lsaquo'    => pack('U', 8249),
  'rsaquo'    => pack('U', 8250),
  'oline'     => pack('U', 8254),
  'frasl'     => pack('U', 8260),
  'euro'      => pack('U', 8364),
  'image'     => pack('U', 8465),
  'weierp'    => pack('U', 8472),
  'real'      => pack('U', 8476),
  'trade'     => pack('U', 8482),
  'alefsym'   => pack('U', 8501),
  'larr'      => pack('U', 8592),
  'uarr'      => pack('U', 8593),
  'rarr'      => pack('U', 8594),
  'darr'      => pack('U', 8595),
  'harr'      => pack('U', 8596),
  'crarr'     => pack('U', 8629),
  'lArr'      => pack('U', 8656),
  'uArr'      => pack('U', 8657),
  'rArr'      => pack('U', 8658),
  'dArr'      => pack('U', 8659),
  'hArr'      => pack('U', 8660),
  'forall'    => pack('U', 8704),
  'part'      => pack('U', 8706),
  'exist'     => pack('U', 8707),
  'empty'     => pack('U', 8709),
  'nabla'     => pack('U', 8711),
  'isin'      => pack('U', 8712),
  'notin'     => pack('U', 8713),
  'ni'        => pack('U', 8715),
  'prod'      => pack('U', 8719),
  'sum'       => pack('U', 8721),
  'minus'     => pack('U', 8722),
  'lowast'    => pack('U', 8727),
  'radic'     => pack('U', 8730),
  'prop'      => pack('U', 8733),
  'infin'     => pack('U', 8734),
  'ang'       => pack('U', 8736),
  'and'       => pack('U', 8743),
  'or'        => pack('U', 8744),
  'cap'       => pack('U', 8745),
  'cup'       => pack('U', 8746),
  'int'       => pack('U', 8747),
  'there4'    => pack('U', 8756),
  'sim'       => pack('U', 8764),
  'cong'      => pack('U', 8773),
  'asymp'     => pack('U', 8776),
  'ne'        => pack('U', 8800),
  'equiv'     => pack('U', 8801),
  'le'        => pack('U', 8804),
  'ge'        => pack('U', 8805),
  'sub'       => pack('U', 8834),
  'sup'       => pack('U', 8835),
  'nsub'      => pack('U', 8836),
  'sube'      => pack('U', 8838),
  'supe'      => pack('U', 8839),
  'oplus'     => pack('U', 8853),
  'otimes'    => pack('U', 8855),
  'perp'      => pack('U', 8869),
  'sdot'      => pack('U', 8901),
  'lceil'     => pack('U', 8968),
  'rceil'     => pack('U', 8969),
  'lfloor'    => pack('U', 8970),
  'rfloor'    => pack('U', 8971),
  'lang'      => pack('U', 9001),
  'rang'      => pack('U', 9002),
  'loz'       => pack('U', 9674),
  'spades'    => pack('U', 9824),
  'clubs'     => pack('U', 9827),
  'hearts'    => pack('U', 9829),
  'diams'     => pack('U', 9830),
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
	
	$text=~s/\s+/ /g; $text=~s/^ //; $text=~s/ $//;
	
	if ($cmd eq 'head1') {
		if ($text=~/\S/) {
			$self->{viewer}->SetHead1Mode(1);
			$self->{viewer}->StartParagraph;
			$self->{viewer}->SetLinkAnchor($text);
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
			$self->{viewer}->SetHead1Mode(0);
		}
		return;
	}
	if ($cmd eq 'head2') {
		if ($text=~/\S/) {
			$self->{viewer}->SetHead2Mode(1);
			$self->{viewer}->StartParagraph;
			$self->{viewer}->SetLinkAnchor($text);
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
			$self->{viewer}->SetHead2Mode(0);
		}
		return;
	}
	if ($cmd eq 'head3') {
		if ($text=~/\S/) {
			$self->{viewer}->SetHead3Mode(1);
			$self->{viewer}->StartParagraph;
			$self->{viewer}->SetLinkAnchor($text);
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
			$self->{viewer}->SetHead3Mode(0);
		}
		return;
	}
	if ($cmd eq 'head4') {
		if ($text=~/\S/) {
			$self->{viewer}->SetHead4Mode(1);
			$self->{viewer}->StartParagraph;
			$self->{viewer}->SetLinkAnchor($text);
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
			$self->{viewer}->SetHead4Mode(0);
		}
		return;
	}
	
	if ($cmd eq 'over') {
		$self->{viewer}->SetIndent($text || 4);
		return;
	}
	if ($cmd eq 'item') {
		if ($text=~/\S/) {
			$self->{viewer}->SetItemMode(1);
			$self->{viewer}->StartParagraph;
			$self->{viewer}->SetLinkAnchor($text);
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
			$self->{viewer}->SetItemMode(0);
		}
		return;
	}
	if ($cmd eq 'back') {
		$self->{viewer}->SetIndent(0);
		return;
	}
	
	if ($cmd eq 'begin') {
		$self->{viewer}->SetFormatMode($text, 1);
		return;
	}
	
	if ($cmd eq 'end') {
		$self->{viewer}->SetFormatMode($text, 0);
		return;
	}
	
	if ($cmd eq 'for') {
		$text=~s/(\S+)\s+//;
		my $format = $1;
		if ($text=~/\S/) {
			$self->{viewer}->SetFormatMode($format, 1);
			$self->{viewer}->StartParagraph;
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
			$self->{viewer}->SetFormatMode($format, 0);
		}
		return;
	}
	
	if ($cmd eq 'pod') {
		if ($text=~/\S/) {
			$self->{viewer}->StartParagraph;
			my $parse_tree = $self->parse_text($text, $line_num);
			$self->display_tree($parse_tree);
			$self->{viewer}->EndParagraph;
		}
		return;
	}
	
	if ($cmd eq 'encoding') {
		$self->{viewer}->SetEncoding($text);
		return;
	}
	
	$self->{viewer}->SetUnknownMode(1);
	$self->{viewer}->StartParagraph;
	$self->{viewer}->Display($cmd . ' ' . $text);
	$self->{viewer}->EndParagraph;
	$self->{viewer}->SetUnknownMode(0);
}

# verbatim paragraphs should not be parsed for formatting codes; they are usually code samples
sub verbatim {
	my ($self, $text, $line_num, $pod_para) = @_;
	
	return unless $text=~/\S/;
	$text=~s/\s+$//;
	
	$self->{viewer}->StartParagraph;
	$self->{viewer}->SetVerbatimMode(1);
	$self->{viewer}->Display($text);
	$self->{viewer}->SetVerbatimMode(0);
	$self->{viewer}->EndParagraph;
}

# ordinary block of text; it can have formatting codes
sub textblock {
	my ($self, $text, $line_num, $pod_para) = @_;
	
	return unless $text=~/\S/;	
	
	$text=~s/\s+/ /g; $text=~s/^ //; $text=~s/ $//;
	my $parse_tree = $self->parse_text($text, $line_num);
	
	$self->{viewer}->StartParagraph;
	$self->display_tree($parse_tree);
	$self->{viewer}->EndParagraph;
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
			$u = pack('U',hex $e);
		}
		elsif ($e=~/^0\d+$/) {
			$u = pack('U',oct $e);
		}
		elsif ($e=~/^\d+$/) {
			$u = pack('U', $e);
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
		$self->{viewer}->SetIndexMark($parse_tree->raw_text);
		#
		# here set up indexing if we want to support that
		#
		return;
	}
	
	# S<text> (do not wrap)
	if ($cmd eq 'S') {
		$self->{viewer}->SetSMode(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetSMode(0);
		return;
	}
	
	# B<text> (bold)
	if ($cmd eq 'B') {
		$self->{viewer}->SetBMode(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetBMode(0);
		return;
	}
	
	# I<text> (italic)
	if ($cmd eq 'I') {
		$self->{viewer}->SetIMode(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetIMode(0);
		return;
	}
	
	# C<text> (code)
	if ($cmd eq 'C') {
		$self->{viewer}->SetCMode(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetCMode(0);
		return;
	}
	
	# F<text> (filename)
	if ($cmd eq 'F') {
		$self->{viewer}->SetFMode(1);
		$self->display_tree($parse_tree);
		$self->{viewer}->SetFMode(0);
		return;
	}
	
	# L<text|name> (link to pod page)
	# L<text|name/"sec"> OR L<text|name/sec> (link to section)
	# L<text|/"sec"> OR L<text|/sec> OR L<text|"sec"> (link to section in this page)
	#   NOTE: text| is optional; without it, default to contents
	# L<scheme:> (link to http, ftp, whatever; no text| option)
	if ($cmd eq 'L') {
		my $target = $parse_tree->raw_text;
		my $text;
		if ($target=~s/^(.+?)\|//) {
			$text = $1;
		}
		else {
			my ($page, $section) = split m:/:, $target;
			if ($section) {
				$page ||= 'this page';
				$text = "$section in $page";
			}
			else {
				$text = $target;
				$text=~s/^"//;
				$text=~s/"$//;
			}
		}
		
		$self->{viewer}->SetLMode(1);
		$self->{viewer}->DisplayLink($text, $target);
		$self->{viewer}->SetLMode(0);
		return;
	}
	
	$self->{viewer}->SetUnknownMode(1);
	$self->{viewer}->Display($sequence->raw_text);
	$self->{viewer}->SetUnknownMode(0);
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

sub begin_pod {
	my ($self) = @_;
	$self->{viewer}->Reset;
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
