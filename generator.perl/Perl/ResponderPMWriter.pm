package Perl::ClassGenerator;
use strict;

sub write_responder_pm_file {
	my ($self, $def) = @_;
	
	# determine file name and open file
	(my $filename = $def->{target})=~s!::!/!g;
	$filename = "$self->{folder}/lib/$filename.pm";
	$self->verify_path_for_file($filename);
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	my $version = $self->version;
	
	print OUT <<FILE;
#
# Automatically generated file
#

package $def->{target};
use strict;
use warnings;

our \@ISA = qw($self->{def}{target});
our \$VERSION = '$version';

1;
FILE
	
	close OUT;
	
	$self->{responder_pm_filename} = $filename;
}

1;
