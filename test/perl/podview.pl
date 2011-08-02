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

$Haiku::ApplicationKit::DEBUG = 0;
$Haiku::InterfaceKit::DEBUG = 0;

my $podviewer = new PodViewer::Application;

print "Getting initial POD\n";

$podviewer->{window}->Lock;

#$podviewer->{window}->{podview}->get_module('perltoc');
$podviewer->{window}->get_perlfunc('pack');
#$podviewer->{window}->{podview}->Display(<<TEXT);
#Some test text goes here to see how things work.
#
#Hooray!
#TEXT

$podviewer->{window}->Unlock;

print "Calling Run()\n";

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

