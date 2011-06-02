package Perl::ClassGenerator;
use strict;

sub write_basic_pm_file {
	my ($self) = @_;
	
	# determine file name and open file
	(my $filename = $self->{def}{target})=~s!::!/!g;
	$filename = "$self->{folder}/lib/$filename.pm";
	$self->verify_path_for_file($filename);
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	my $version = $self->version;
	
	print OUT <<INTRO;
#
# Automatically generated file
#

package $self->{def}{target};
use strict;
use warnings;

our \$VERSION = '$version';

INTRO

	my (@isa, @constants);
	
	# determine whether we need to export anything
	if ($self->{constants}) {
		print OUT "require Exporter;\n";
		push @isa, 'Exporter';
		for my $constant (@{ $self->{constants} }) {
			push @constants, $constant->{name};
		}
	}
	print OUT "\n";
	
	# determine what kind of inheritance we have
	if ($self->{def}{'target-inherits'}) {
		push @isa, split /\s*, \s*/, $self->{def}{'target-inherits'};
	}
	
	if (@isa) {
		print OUT 'our @ISA = qw(', join(' ', @isa), ");\n";
	}
	
	if (@constants) {
		print OUT 'our @EXPORT_OK = qw(', join(' ', @constants), ");\n";
	}
	
	print OUT qq(our \$VERSION = '0.01';	# need to fix this\n);
	
	print OUT "\n1;\n";
	
	close OUT;
	
	$self->{basic_pm_filename} = $filename;
}

1;
