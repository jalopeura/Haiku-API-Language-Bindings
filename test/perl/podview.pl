# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

use Haiku::SupportKit;
use Haiku::ApplicationKit;
use Haiku::InterfaceKit;
use PodViewer::Application;

#$SIG{__WARN__} = sub {
#	new Haiku::Alert(
#		"Warning",	# title
#		$_[0],	# text
#		'Ok',	# button 1 label
#	)->Go;
#};

$Haiku::ApplicationKit::DEBUG = 0;
$Haiku::InterfaceKit::DEBUG = 0;

my $podviewer = new PodViewer::Application;

$podviewer->{window}->Lock;

$podviewer->{window}->{parser}->parse_from_file($0);

$podviewer->{window}->Unlock;

$podviewer->Run;

=pod

=head1 Graphical POD Viewer

This program works similarly to perl's builtin C<perldoc> utility.
There are four search modes.

=over 4

=item *

Ordinary Search

Allows you to find documentation for Perl itself or for a module. The
search parameter should be the name of the documentation file (for
example, C<perlhaiku> or C<perlpod>) or the name of the module (for
example, C<File::Copy> or C<Tie::Hash>).

=item *

Function Search

Allows you to search for documentation on a builtin function, instead
of loading C<perlfunc> and scanning through it. The parameter should
be the name of the function (for example, C<pack> or C<open>).

=item *

Variable Search

Allows you to search for one of Perl's special variables, instead of
loading C<perlvar> and scanning through it. The parameter should be
the variable name (for example, C<$_> or C<$0>).

=item *

FAQ Search

Allows you to search the FAQ files instead of loading each one
individually and scanning through it. The parameter should be a
regular expression (for example, C<haiku> or C<edit.*>). (Search is
not case-sensitive.)

Be aware that only the questions themselves are searched, not the
answers, although both the question and the answer are displayed when
a match is found.

=back

=cut

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

