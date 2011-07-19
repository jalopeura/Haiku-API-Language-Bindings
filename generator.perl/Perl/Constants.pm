use Common::Constants;
use Perl::BaseObject;

package Perl::Constants;
use strict;
our @ISA = qw(Constants Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('constants')) {
		for my $c ($self->constants) {
			$c->generate;
		}
	}
}

sub get_groups {
	my ($self) = @_;
	my (%groups);
	
	if ($self->has('constants')) {
		for my $c ($self->constants) {
			$groups{ $c->{group} } ||= [];
			push @{ $groups{ $c->{group} } }, $c->name;
		}
	}
	
	return %groups;
}

sub exports {
	my ($self) = @_;
	
	my %groups = $self->get_groups;
	
	my @ret;
	for my $k (sort keys %groups) {
		my $name = $k ? "${k}_group" : 'ungrouped';
		push @ret, "\@$name";
	}
	return \@ret;
}

sub generate_export_groups {
	my ($self) = @_;
	
	my %groups = $self->get_groups;
	my $fh = $self->package->pmh;
	
	print $fh "\n";
	my @tags;
	for my $k (sort keys %groups) {
		my $name = $k ? "${k}_group" : 'ungrouped';
		my $names = join(' ', @{ $groups{$k} });
		print $fh "my \@$name = qw($names);\n";
		next unless $k;
		push @tags, "$k => [\@$name]";
	}
	print $fh "\n";
	
	if (@tags) {
		print $fh
			"our \%EXPORT_TAGS = (\n\t",
			join(",\n\t", @tags),
			"\n);\n";
	}
}

#    @EXPORT = qw(A1 A2 A3 A4 A5);
#    @EXPORT_OK = qw(B1 B2 B3 B4 B5);
#    %EXPORT_TAGS = (T1 => [qw(A1 A2 B1 B2)], T2 => [qw(A1 A2 B3 B4)]);
#    Note that you cannot use tags in @EXPORT or @EXPORT_OK.
#    Names in EXPORT_TAGS must also appear in @EXPORT or @EXPORT_OK.

package Perl::Constant;
use strict;
our @ISA = qw(Constant Perl::BaseObject);

sub type {
	my ($self) = @_;
	unless ($self->{type}) {
		my $t = $self->{type_name};
		if ($self->{needs_deref}) {
			$t=~s/\*$//;
		}
		$self->{type} = $self->types->type($t);
	}
	return $self->{type};
}

sub input_converter {
	my ($self, $target) = @_;
	
	return $self->type->input_converter($self->name, $target);
}

sub output_converter {
	my ($self, $target) = @_;
	
	return $self->type->output_converter($self->name, $target, 1);	# 1 (true) because we can never delete a constant
}

sub generate {
	my ($self) = @_;
	
	my $name = $self->name;
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	my $ctype_to_sv = $self->output_converter('RETVAL');
	
	print { $self->package->xsh } <<CONST;
SV*
$name()
	CODE:
		RETVAL = newSV(0);
		$ctype_to_sv
	OUTPUT:
		RETVAL

CONST
}

1;
