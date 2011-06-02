package Perl::MainClassGenerator;
require Perl::ClassGenerator;
use strict;

our @ISA = qw(Perl::ClassGenerator);

sub write_basic_xs_file {
	my ($self) = @_;
	
	# a lot of things require access to the generator
	my $generator = $self->{def}{generator};
	my $master_include = $self->{def}{generator}{master_include};
	
	my @class_map = $generator->class_map;
	
	# determine file name and open file
#	(my $filename = $self->{def}{target})=~s!::!/!g;
#	$filename = "$self->{folder}/ext/$filename.xs";
#	$self->verify_path_for_file($filename);
#	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	# determine XS file name and open file
	my $filename = "$self->{folder}/$generator->{package}.xs";
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	# write an intro comment
	print OUT <<INTRO;
/*
 * Automatically generated file
 */

#include "$master_include"

INTRO

=pod

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "$generator->{package}.h"

=cut

	
	print OUT <<MOD;
MODULE = $self->{module}	PACKAGE = $self->{def}{target}

MOD
	
	# do imports
	if (@class_map) {
		for my $map (@class_map) {
			(my $file = $map->[1])=~s!::!_!g;
			print OUT qq(INCLUDE: $file.xs\n);
		}
		print OUT "\n";
	}
	
	# force main package again, since the last import may have overwritten it
	print OUT <<MOD;
MODULE = $self->{module}	PACKAGE = $self->{def}{target}

MOD
	
	$self->write_basic_xs_code(\*OUT);
	
	close OUT;
	
	$self->{basic_xs_filename} = $filename;
}

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
	
	print OUT "require DynaLoader;\n";
	push @isa, 'DynaLoader';	# as the main class, we need this
	
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
	
	print OUT <<END;

bootstrap $self->{def}{target} \$VERSION;

1;
END
	
	close OUT;
	
	$self->{basic_pm_filename} = $filename;
}

1;
__END__

