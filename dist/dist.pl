use File::Spec;
use File::Path;
use File::Copy;
use strict;

my $gendir = '../generated';
my @dist = (
	{
		lang         => 'perl',
		prep_subpath => [ 'HaikuKits' ],
		dist_subpath => [ 'HaikuKits' ],
		pattern      => qr/(HaikuKits-[\d.]+)(\.tar\.gz)/,
		commands     => [
			"perl Makefile.PL",
			"make manifest",
			"make dist",
		],
	},
	{
		lang        => 'python',
		prep_subpath => [ 'Haiku' ],
		dist_subpath => [ 'Haiku', 'dist' ],
		pattern      => qr/(Haiku-[\d.]+)(\.tar\.gz)/,
		commands    => [
			"python setup.py sdist",
		],
	},
);

my @t = gmtime;
my $stamp = sprintf('%04d%02d%02d-%02d%02d%02d', $t[5]+1900, $t[4]+1, @t[3,2,1,0]);
mkpath($stamp);

my $curdir = File::Spec->rel2abs(File::Spec->curdir),"\n";

for my $dist (@dist) {
	# set up variables
	my ($lang, $prep_subpath, $dist_subpath, $pattern, $commands)
		= @$dist{qw(lang prep_subpath dist_subpath pattern commands)};
	my $prep_folder = File::Spec->rel2abs(
		File::Spec->catdir($gendir, $lang, @$prep_subpath)
	);
	my $dist_folder = File::Spec->rel2abs(
		File::Spec->catdir($gendir, $lang, @$dist_subpath)
	);
	
print "Moving into prep folder '$prep_folder'\n";
	# create the distributions
	chdir($prep_folder);
	for my $cmd (@$commands) {
		system $cmd;
	}
	
print "Returning to folder '$curdir'\n\n";
	chdir($curdir);
	
print "Searching dist folder '$dist_folder'\n";
	opendir DIR, $dist_folder or die "Unable to read folder '$dist_folder': $!";
	while (my $e = readdir DIR) {
		next unless $e=~/$pattern/;
		my $target = File::Spec->catfile($stamp, join('_', $lang, $1, $stamp) . $2);
		my $source = File::Spec->catfile($dist_folder, $e);
print "\t$e => $source => $target\n";
		copy($source, $target);
	}
print "\n";
	
}

