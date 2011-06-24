use File::Spec;
use File::Path;
use File::Copy;
use strict;

my $gendir = '../generated';
my @dist = (
	['perl',   'HaikuKits',      qr/(HaikuKits-[\d.]+)(\.tar\.gz)/],
	['python', 'HaikuKits/dist', qr/(HaikuKits-[\d.]+)(\.tar\.gz)/],
);

my @t = gmtime;
my $stamp = sprintf('%04d%02d%02d-%02d%02d%02d', $t[5]+1900, $t[4]+1, @t[3,2,1,0]);
mkpath($stamp);

for my $dist (@dist) {
	my ($lang, $subpath, $pattern) = @$dist;
	my $folder = File::Spec->catdir($gendir, $lang, $subpath);
	opendir DIR, $folder or die "Unable to read folder '$folder': $!";
print $folder,"\n";
	while (my $e = readdir DIR) {
		next unless $e=~/$pattern/;
		my $target = File::Spec->catfile($stamp, join('_', $lang, $1, $stamp) . $2);
		my $source = File::Spec->catfile($folder, $e);
print "\t$e => $source => $target\n";
		copy($source, $target);
	}
print "\n";
}
