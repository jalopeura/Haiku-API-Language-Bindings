# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

use PodViewer::Application;
#use Haiku::ApplicationKit;
#use Haiku::InterfaceKit;
#use Haiku::SupportKit;

$Haiku::ApplicationKit::DEBUG = 4;
$Haiku::InterfaceKit::DEBUG = 4;

my $podviewer = new PodViewer::Application;

$podviewer->{window}->Lock;

#$podviewer->{window}->get_module('perltoc');
$podviewer->{window}->get_module('perlpod');
#$podviewer->{window}->get_perlfunc('pack');
#$podviewer->{window}->get_perlfunc('oct');
#$podviewer->{window}->{parser}->parse_from_file($0);

=pod

S<Here's some non-wrapping stuff (theoretically)>

Here's some stuff at the beginning

Here's some escapes:
via code: E<ecirc>
via octal: E<0352>
via decimal: E<234>
via hexadecimal: E<0xea>

B<Bold text>

I<Italic text>

B<Bold and I<Italic> text>

L<link text|page/section>

Here's some after stuff

    Here's some verbatim stuff

S<Here's some non-wrapping stuff (theoretically)>

Here's a F<filename>

Here's some Q<Unknown>

=cut

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

