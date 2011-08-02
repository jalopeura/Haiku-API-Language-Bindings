# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

package ArrayAsFile;
use strict;

use constant POS_IN_FILE => 0;
use constant LINE_NUMBER => 1;
use constant POS_IN_LINE => 2;

sub TIEHANDLE {
	my ($class, $aref) = @_;
	
	my $self = bless {
		data => $aref,
		data_offsets => [],
	}, $class;
	
	my $offset;
	for my $i (0..$#$aref) {
		$self->{data_offsets}[$i] = $offset;
		$offset += length($aref->[$i]);
	}
	$self->{size} = $offset;
	$self->{position} = 0;
	
	return $self;
}

sub TELL {
	my ($self) = @_;
	return $self->{position};
}

sub SEEK {
	my ($self, $position, $whence) = @_;
	
	if ($whence == 0) {	# START + $position
		$self->{position} = $position;
	}
	
	if ($whence == 1) {	# CURRENT + position
		$self->{position} += $position;
	}
	
	if ($whence == 2) {	# END + $position
		$self->{position} = $self->{size} + $position;
	}
}

sub get_line_and_offset {
	my ($self) = @_;
	
	my $line = 0;
	while ($line <= $#{ $self->{data} }) {
		last if ($self->{data_offsets}[$line] > $self->{position});
		$line++;
	}
	$line--;
	
	my $offset = $self->{position} - $self->{data_offsets}[$line];
	
	return ($line, $offset);
}

sub READ {
	my($self, undef, $len, $offset) = @_;
	
	if ($self->{position} >= $self->{size}) {
		return undef;
	}
	
	my ($data_line, $data_offset) = $self->get_line_and_offset;
	
	# get the rest of the current line
	my $data = $self->{data}[$data_line];
	if ($data_offset) {
		substr($data, 0, $data_offset, '');
	}
	
	# if they wanted more, give them more
	while (length($data) < $len) {
		$data .= $self->{data}[++$data_line];
		last if ($data_line >= $#{ $self->{data} });
	}
	
	# if we got too much, chop off the end
	if (length($data) > $len) {
		substr($data, $len, length($data), '');
	}
	
	$len = length($data);	# length actually read may be less than requested
	$self->{position} += $len;
	$_[1] = $data;
	return $len;
}

sub READLINE {
	my ($self) = @_;
	
	if ($self->{position} >= $self->{size}) {
		return wantarray ? () : undef;
	}
	
	my ($data_line, $data_offset) = $self->get_line_and_offset;
	
	# get the rest of the current line
	my $data = $self->{data}[$data_line];
	if ($data_offset) {
		substr($data, 0, $data_offset, '');
	}
	
	if (wantarray) {
		my @data = ($data);
		while ($data_line <= $#{ $self->{data} }) {
			push @data, $self->{data}[++$data_line];
		}
		$self->{position} = $self->{size};
		return @data;
	}
	
	$self->{position} += length($data);
	return $data;
}

sub CLOSE {}

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
#print "START VERBATIM:\n\n";
	$self->{viewer}->Display($text);
#print "END VERBATIM:\n\n";
#print <<INFO;
#VERBATIM
#TXT: $text
#LN#: $line_num
#
#INFO
}

# ordinary block of text; it can have formatting codes
sub textblock {
	my ($self, $text, $line_num, $pod_para) = @_;
	
	#
	# here handle starting a new paragraph
	#
#print "START TEXTBLOCK:\n\n";
	
	$text=~s/\s+/ /g; $text=~s/^ //; $text=~s/ $//;
	my $parse_tree = $self->parse_text($text, $line_num);
	$self->display_tree($parse_tree);	# can add other args (like text_run) later
#print "END TEXTBLOCK:\n\n";
}

sub display_tree {
	my ($self, $parse_tree) = @_;
	
	for my $child ($parse_tree->children) {
		if (ref $child) {
#print "Doing a sequence\n";
			$self->display_sequence($child);
		}
		else {
#print "Doing plain text\n";
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
			$u = $entity2char{$e} || $e
		}
		#
		# here just display the text
		#
		$self->{viewer}->Display($u);
		return;
	}
	
	
	# S<text> (do not wrap)
	if ($cmd eq 'S') {
		my $text = $parse_tree->raw_text;
		$text=~s/ /\xa0/;
	}
	# X<topic> (for creating indexes; render as an empty string)
#	elsif ($cmd eq 'X') {
#		#
#		# here set up indexing if we want to support that
#		#
#	}
	
	# if we're an E<, a Z<, an X<, we simply display the necessary text and we're done
	
	# if we're an S<, we replaced spaces with non-breaking spaces and display the text and we're done
	
	#
	# the following codes alter the appearance
	#

	# I<text>
	# B<text>
	# C<text> (code)
	# L<text|name> (link to pod page)
	# L<text|name/"sec"> OR L<text|name/sec> (link to section)
	# L<text|/"sec"> OR L<text|/sec> OR L<text|"sec"> (link to section in this page)
	#   NOTE: text| is optional; without it, default to contents
	# L<scheme:> (link to http, ftp, whatever; no text| option)
	# F<filename> (typically displayed in italics)
	
	#
	# here save out the current display options and set new ones
	#
#print "START INTERIOR SEQUENCE ($cmd):\n\n";
	$self->display_tree($parse_tree);
#print "END INTERIOR SEQUENCE ($cmd):\n\n";
	#
	# here restore current display options
	#
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

package PodViewer::PodView;
use strict;
our @ISA = qw(Haiku::TextView);

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new(@_);
	
	$self->{parser} = new PodView::Parser($self);
	
	$self->{parser}->errorsub(sub { $self->pod_error });
	
	return $self;
}

sub Display {
	my ($self, $text) = @_;

#print "Inserting $text\n";
	$self->Insert($text);
	$self->Invalidate;
}

#
# Much of the following code was adapted from Pod::Perldoc
#

sub get_module {
	my ($self, $module) = @_;
	
	(my $module_file = $module)=~s+::+/+g;
	
	my $file = $self->get_podfile($module_file) or
		warn "No POD file found for module '$module'" and
		return undef;
	
	open my $fh, $file or die "Unable to read file '$file': $!";
	
	$self->{parser}->parse_from_filehandle($fh);
	
	close $fh;
}

sub get_perlfunc {
	my ($self, $func) = @_;
	
	my $file = $self->get_podfile('perlfunc');
	
	open FILE, $file or die "Unable to read file '$file': $!";
	
	# dashed functions are all listed as -X; everything else should be escaped
	my $search_func = $func=~/^-[rwxoRWXOeszfdlpSbctugkTBMAC]$/ ?
		'(?:I<)?-X' :
		quotemeta($func);

    # Skip introduction
	while (<FILE>) {
		last if /^=head2 Alphabetical Listing of Perl Functions/;
	}
	
	my (@lines, $found, $inlist);
	while (<FILE>) {
		if ( m/^=item\s+$search_func\b/ )  {
			$found = 1;
		}
		elsif (/^=item/) {
			last if $found > 1 and not $inlist;
		}
		next unless $found;
		
		if (/^=over/) {
			++$inlist;
		}
		elsif (/^=back/) {
			--$inlist;
		}
		
		push @lines, $_;
		++$found if /^\w/;	# found descriptive text
	}
	close FILE;
	
	@lines or 
		warn "No documentation found for perl function '$func'" and
		return undef;
	
	tie *FH, 'ArrayAsFile', \@lines;
	
	$self->{parser}->parse_from_filehandle(*FH);
	
	close FH;
}

sub get_perlvar {
	my ($self, $var) = @_;
	
	my $file = $self->get_podfile('perlvar');
	
	open FILE, $file or die "Unable to read file '$file': $!";
	
	# digit vars are all listed as $digit
	(my $search_var = $var)=~s/^\$[1-9]$/\$<I<digits>>/;
    $search_var = quotemeta($search_var);

	# Skip introduction
	while (<FILE>) {
		last if /^=over 8/;
	}

	# Look for our variable
	my (@lines, $found, $inlist);
	my $inheader = 1;
	while (<FILE>) {
		last if /^=head2 Error Indicators/;
		
		# \b at the end of $` and friends borks things!
		if (m/^=item\s+$search_var\s/)  {
			$found = 1;
		}
		elsif (/^=item/) {
			last if $found && !$inheader && !$inlist;
		}
		elsif (!/^\s+$/) { # not a blank line
			if ($found) {
				$inheader = 0;	# don't accept more =item (unless inlist)
			}
			else {
				@lines = ();	# reset
				$inheader = 1;	# start over
				next;
			}
		}
		
		if (/^=over/) {
			++$inlist;
		}
		elsif (/^=back/) {
			--$inlist;
		}
		push @lines, $_;
		#++$found if /^\w/;	# found descriptive text
	}
	close FILE;
	
	@lines = () unless $found;
	
	@lines or 
		warn "No documentation found for perl variable '$var'" and
		return undef;
	
	tie *FH, 'ArrayAsFile', \@lines;
	
	$self->{parser}->parse_from_filehandle(*FH);
	
	close FH;
}

sub get_perlfaq {
	my ($self, $faq_rx) = @_;
	
	my $search_faq = eval { qr/$faq_rx/ } or
		warn "Invalid regular expression '$faq_rx'";
	
	my (@lines, $found, %found_in);
	for my $n (1..9) {
		my $file = $self->get_podfile("perlfaq$n");
		
		open FILE, $file or die "Unable to read file '$file': $!";
		while (<FILE>) {
			if ( m/^=head2\s+.*(?:$search_faq)/i ) {
				$found = 1;
				push @lines, "=head1 Found in $file\n\n" unless $found_in{$file}++;
			}
			elsif (/^=head[12]/) {
				$found = 0;
			}
			next unless $found;
			push @lines, $_;
		}
		close FILE;
	}
	@lines or 
		warn "No documentation found for perl FAQ keyword '$faq_rx'" and
		return undef;
	
	tie *FH, 'ArrayAsFile', \@lines;
	
	$self->{parser}->parse_from_filehandle(*FH);
	
	close FH;
}

sub get_podfile {
	my ($self, $file) = @_;
	
	my @files = (
		"$file.pod",
		"$file.pm",
		$file,
		"pod/$file.pod",
		"pod/$file",
		"pods/$file.pod",
		"pods/$file",
	);
	
	for my $dir (@INC) {
		for my $file (@files) {
			-e "$dir/$file" and $self->check_for_pod("$dir/$file") and return "$dir/$file";
		}
	}
	
	# if we get here, we found no pod
	return undef;
}

sub check_for_pod {
	my ($self, $file) = @_;
	
	open TEST, $file or die "Unable to read file '$file': $!";
	while (<TEST>) {
		if (/^=head/) {
			close TEST or die "Can't close file '$file': $!";
			return 1;
		}
	}
	close TEST;
	
	return undef;
}

sub pod_error {
	print join("\n", 'pod_error', @_),"\n\n";
}

package PodViewer::Application;
use Haiku::CustomApplication;
use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use strict;
our @ISA = qw(Haiku::CustomApplication);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new("application/x-podviewer", @args);

	$self->{window} = new PodViewer::Window(
		new Haiku::Rect(50,50,170,170),	# frame
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

sub MessageReceived {
	my ($self, $message) = @_;
#warn "\nMessageReceived($self, $message)\n\n";
	$self->SUPER::MessageReceived($message);
}

package PodViewer::Window;
use Haiku::CustomWindow;
use Haiku::View qw(B_FOLLOW_ALL B_WILL_DRAW B_NAVIGABLE);
use strict;
our @ISA = qw(Haiku::CustomWindow);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	my $f = $args[0];
	my $w = $f->right - $f->left;
	my $h = $f->bottom - $f->top;
	
	$self->{podview} = new PodViewer::PodView(
		new Haiku::Rect(0,0,$w,$h),	# frame
		"TestButton",	# name
		new Haiku::Rect(5,5,$w-5,$h-5),	# textRect
		B_FOLLOW_ALL,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
	);
	
	$self->AddChild($self->{podview}, 0);
	
	return $self;
}

sub MessageReceived {
	my ($self, $message) = @_;
	$self->{message_count}++;
	my $what = $message->what();
#my $text = unpack('A*', pack('L', $what));
#print "$what => $text\n";

	$self->SUPER::MessageReceived($message);
}

sub FrameResized {
	my ($self, $w, $h) = @_;

	my $gap = 5;
	
	$self->{podview}->SetTextRect(
		Haiku::Rect->new($gap,$gap,$w-$gap,$h-$gap)
	);
}

package main;
use Haiku::ApplicationKit;
use Haiku::InterfaceKit;
use Haiku::SupportKit;

$Haiku::ApplicationKit::DEBUG = 0;
$Haiku::InterfaceKit::DEBUG = 0;

my $podviewer = new PodViewer::Application;

$podviewer->{window}->Lock;

#$podviewer->{window}->{podview}->get_module('perltoc');
$podviewer->{window}->{podview}->get_perlfunc('pack');
#$podviewer->{window}->{podview}->Display(<<TEXT);
#Some test text goes here to see how things work.
#
#Hooray!
#TEXT

$podviewer->{window}->Unlock;

$podviewer->Run;

__END__

#my $file = "$INC[0]/pods/perlfunc.pod";
my $file = "$INC[0]/pods/perlxs.pod";

#$podview->{parser}->parse_from_file($file);
#$podview->{parser}->parse_from_file($0);

open LOG, '>podview.log' or die $!;

for my $m (qw(Pod::Simple Does::Not::Exist)) {
	my $fh = $podview->get_module($m);
	
	$fh or next;
	
	print LOG "MODULE $m\n\n";
	while (<$fh>) {
		print LOG;
	}
	close $fh;
	print LOG "\n\n";
}

for my $f (qw(-e close flargle)) {
	my $fh = $podview->get_perlfunc($f);
	
	$fh or next;
	
	print LOG "FUNCTION $f\n\n";
	while (<$fh>) {
		print LOG;
	}
	close $fh;
	print LOG "\n\n";
}

for my $q (qw(Windows flargle)) {
	my $fh = $podview->get_perlfaq($q);
	
	$fh or next;
	
	print LOG "QUESTION $q\n\n";
	while (<$fh>) {
		print LOG;
	}
	close $fh;
	print LOG "\n\n";
}

for my $v (qw($0 $1 $@ $| $flargle)) {
	my $fh = $podview->get_perlvar($v);
	
	$fh or next;
	
	print LOG "VARIABLE $v\n\n";
	while (<$fh>) {
		print LOG;
	}
	close $fh;
	print LOG "\n\n";
}

