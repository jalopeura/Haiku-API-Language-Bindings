package PodViewer::Window;
use Haiku::SupportKit;
use Haiku::InterfaceKit;
use PodViewer::PodView;
use PodViewer::Parser;
use PodViewer::ArrayAsFile;
use Haiku::View qw(B_FOLLOW_ALL B_FOLLOW_TOP B_FOLLOW_LEFT_RIGHT B_WILL_DRAW B_NAVIGABLE);
use Haiku::ScrollBar qw(B_V_SCROLL_BAR_WIDTH B_H_SCROLL_BAR_HEIGHT);
use strict;
our @ISA = qw(Haiku::CustomWindow);

use constant SEARCH_ORDINARY => 0xffff0001;
use constant SEARCH_FUNC     => 0xffff0002;
use constant SEARCH_VAR      => 0xffff0003;
use constant SEARCH_FAQ      => 0xffff0004;

use constant DO_SEARCH       => 0xffff0104;

my $buffer_size = 5;
my $horizontal_scroll = 0;
my $vertical_scroll = 1;

sub MouseMoved {
	print "MouseMoved\n";
	my $self = shift;
	$self->SUPER::MouseMoved(@_);
}

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	my $l = 0;
	my $t = 0;
	
	my $f = $args[0];
	my $w = $f->right - $f->left;
	my $h = $f->bottom - $f->top;
	
	#
	# search menu
	#
	
	my $ch = 20;	# control height
	my $mw = 125;	# menu width
	
	$self->{searchmenu} = new Haiku::PopUpMenu("search");
	$self->{searchmenu}->SetRadioMode(1);
	
	my @items;
	push @items, new Haiku::MenuItem(
		"Ordinary Search",
		new Haiku::Message(SEARCH_ORDINARY),
	);
	push @items, new Haiku::MenuItem(
		"Function Search",
		new Haiku::Message(SEARCH_FUNC),
	);
	push @items, new Haiku::MenuItem(
		"Variable Search",
		new Haiku::Message(SEARCH_VAR),
	);
	push @items, new Haiku::MenuItem(
		"FAQ Search",
		new Haiku::Message(SEARCH_FAQ),
	);
	for my $item (@items) {
		$self->{searchmenu}->AddItem($item);
	}
	$self->{searchmenu}->SetTargetForItems($self);
	$items[0]->SetMarked(1);
	
	$self->{searchmenufield} = Haiku::MenuField->newFixedSize(
		new Haiku::Rect($l,$t,$l+$mw,$t+$ch),
		"SearchType",
		"Ordinary Search",
		$self->{searchmenu},
		1,	# fixed size
	);
	
	$self->{searchmenufield}->SetDivider(0);
	
	$self->AddChild($self->{searchmenufield}, 0);
	
	#
	# search field
	#
	
	$l += $mw + $buffer_size;
	
	my $tw = $w - $l;
	
	$self->{searchfield} = new Haiku::TextControl(
		new Haiku::Rect($l,0,$l+$tw,$t+$ch),
		"SearchField",	# name
		"",	# label
		"",	# text
		new Haiku::Message(DO_SEARCH),
		B_FOLLOW_LEFT_RIGHT | B_FOLLOW_TOP,	# resizing
	);
	$self->{searchfield}->SetDivider(0);
	
	$self->AddChild($self->{searchfield}, 0);
	
	#
	# pod viewer
	#
	
	$t += $ch + $buffer_size;
	$h -= $ch + $buffer_size;
	
	$l = 0;
	
	if ($vertical_scroll) {
		$w -= B_V_SCROLL_BAR_WIDTH;
	}
	if ($horizontal_scroll) {
		$h -= B_H_SCROLL_BAR_HEIGHT;
	}
	
	$self->{podview} = new PodViewer::PodView(
		new Haiku::Rect($l,$t,$l+$w,$t+$h),	# frame
		"PodView",	# name
		new Haiku::Rect(
			$buffer_size,$buffer_size,
			$w-$buffer_size,$h-$buffer_size
		),	# textRect
		B_FOLLOW_ALL,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
	);
	
	$self->{scrollview} = new Haiku::ScrollView(
		"ScrollView",	# name
		$self->{podview},	# target
		B_FOLLOW_ALL,	# resizingMode
		B_WILL_DRAW | B_NAVIGABLE,	# flags
		$horizontal_scroll,	# horizontal
		$vertical_scroll,	# vertical
	);
	
	$self->AddChild($self->{scrollview}, 0);
	
	$self->{parser} = new PodView::Parser($self->{podview});
	
	$self->{parser}->errorsub(sub { $self->pod_error });
	
	$self->{searchtype} = SEARCH_ORDINARY;
	
	return $self;
}

sub MessageReceived {
	my ($self, $message) = @_;
	
	my $what = $message->what;
	
	if ($what == SEARCH_ORDINARY) {
		$self->{searchtype} = SEARCH_ORDINARY;
		return;
	}
	if ($what == SEARCH_FUNC) {
		$self->{searchtype} = SEARCH_FUNC;
		return;
	}
	if ($what == SEARCH_VAR) {
		$self->{searchtype} = SEARCH_VAR;
		return;
	}
	if ($what == SEARCH_FAQ) {
		$self->{searchtype} = SEARCH_FAQ;
		return;
	}
	
	if ($what == DO_SEARCH) {
		$self->search_for_pod($self->{searchfield}->Text);
		return;
	}
	
	$self->SUPER::MessageReceived($message);
}

sub FrameResized {
	my ($self, $w, $h) = @_;
	
	$self->{podview}->SetTextRect(
		Haiku::Rect->new(
			$buffer_size,$buffer_size,
			$w-$buffer_size,$h-$buffer_size
		)
	);
}

sub search_for_pod {
	my ($self, $term) = @_;
	
	my $type = $self->{searchtype};
	
	if ($type == SEARCH_ORDINARY) {
		$self->get_module($term);
		return;
	}
	if ($type == SEARCH_FUNC) {
		$self->get_perlfunc($term);
		return;
	}
	if ($type == SEARCH_VAR) {
		$self->get_perlvar($term);
		return;
	}
	if ($type == SEARCH_FAQ) {
		$self->get_perlfaq($term);
		return;
	}
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
	
#	open my $fh, $file or die "Unable to read file '$file': $!";
	
	$self->{parser}->parse_from_file($file);
	$self->SetTitle($module);
	
#	close $fh;
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
		
		# any relative links should become absolute
		s:L<(.+?\|)?/:L<$1perlfunc/:;
		s:L<(.+?\|)?":L<$1perlfunc/":;
		
		push @lines, $_;
		++$found if /^\w/;	# found descriptive text
	}
	close FILE;
	
	@lines or 
		warn "No documentation found for perl function '$func'" and
		return undef;
	
	tie *FH, 'ArrayAsFile', \@lines;
	
	$self->{parser}->parse_from_filehandle(*FH);
	$self->SetTitle("Function: $func");
	
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
		
		# any relative links should become absolute
		s:L<(.+?\|)?/:L<$1perlvar/:;
		s:L<(.+?\|)?":L<$1perlvar/":;
		
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
	$self->SetTitle("Variable: $var");
	
	close FH;
}

sub get_perlfaq {
	my ($self, $faq_rx) = @_;
	
	my $search_faq = eval { qr/$faq_rx/i } or
		warn "Invalid regular expression '$faq_rx'";
	
	my (@lines, $found, %found_in);
	for my $n (1..9) {
		my $file = $self->get_podfile("perlfaq$n");
		
		open FILE, $file or die "Unable to read file '$file': $!";
		while (<FILE>) {
			if ( m/^=head2\s+.*(?:$search_faq)/i ) {
				$found = 1;
				push @lines, "=head1 Found in $file\n", "\n" unless $found_in{$file}++;
			}
			elsif (/^=head[12]/) {
				$found = 0;
			}
			next unless $found;
			
			# any relative links should become absolute
			s:L<(.+?\|)?/:L<$1perlfaq$n/:;
			s:L<(.+?\|)?":L<$1perlfaq$n/":;
			
			push @lines, $_;
		}
		close FILE;
	}
	@lines or 
		warn "No documentation found for perl FAQ keyword '$faq_rx'" and
		return undef;
	
	tie *FH, 'ArrayAsFile', \@lines;
	
	$self->{parser}->parse_from_filehandle(*FH);
	$self->SetTitle("FAQ Search: $faq_rx");
	
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

1;

