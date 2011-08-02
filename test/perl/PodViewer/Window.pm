package PodViewer::Window;
use Haiku::InterfaceKit;
use PodViewer::PodView;
use PodViewer::Parser;
use PodViewer::ArrayAsFile;
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
	
	$self->{parser} = new PodView::Parser($self->{podview});
	
	$self->{parser}->errorsub(sub { $self->pod_error });
	
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

1;

