package Perl::Package;
use strict;

sub generate_pm_preamble {
	my ($self) = @_;
	
	my $perl_class_name = $self->{name};
	
	print { $self->{pmh} } <<TOP;
#
# Automatically generated file
#

package $perl_class_name;
use strict;
use warnings;
TOP
	
	if ($self->{dynaloader}) {
		print  { $self->{pmh} } "require DynaLoader;\n"
	}
	
	if ($self->{exports}) {
		print  { $self->{pmh} } "require Exporter;\n"
	}
	
	print { $self->{pmh} } "\nour \$VERSION = $self->{version};\n";
	
	if ($self->{isa}) {
		my $isa = join(' ', @{ $self->{isa} });
		print { $self->{pmh} } "our \@ISA = qw($isa);\n";
	}
	
	if ($self->{exports}) {
		my $exp = join(' ', @{ $self->{exports} });
		print { $self->{pmh} } "our \@EXPORT_OK = qw($exp);\n";
	}
	
	print { $self->{pmh} } "\n";
}

sub generate_pm_function {
	#
	# generate POD
	#
}

sub generate_pm_property {	
	#
	# generate POD
	#
}

sub generate_pm_constant {	
	#
	# generate POD
	#
}

sub generate_pm_postamble {
	my ($self) = @_;
	
	print { $self->{pmh} } "1;\n";
}

1;
