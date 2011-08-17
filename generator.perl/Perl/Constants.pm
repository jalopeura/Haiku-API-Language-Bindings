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
			my @g = split /\s+/, $c->{group};
			for my $g (@g) {
				$groups{ $g } ||= [];
				push @{ $groups{$g} }, $c->name;
			}
		}
	}
	
	return %groups;
}

sub exports {
	my ($self) = @_;
	
	my %groups = $self->get_groups;
	
	my @ret;
	for my $k (sort keys %groups) {
		my $name = $k=~/\S/ ? "${k}_group" : 'ungrouped';
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
		my $name = $k=~/\S/ ? "${k}_group" : 'ungrouped';
		my $names = join(' ', @{ $groups{$k} });
		print $fh "my \@$name = qw($names);\n";
		next unless $k=~/\S/;
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

package Perl::Constant;
use strict;
our @ISA = qw(Constant Perl::BaseObject);

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->{qualified_name} = $self->{name};
	
	$self->{name}=~s/^.*::([^:]+)$/$1/;
}

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

sub is_array_or_string {
	my ($self) = @_;
	
	if ($self->has('array_length') or
		$self->has('string_length') or
		$self->has('max_array_length') or
		$self->has('max_string_length')) {
		return 1;
	}
	
	my $type = $self->type;
	if ($type->has('array_length') or
		$type->has('string_length') or
		$type->has('max_array_length') or
		$type->has('max_string_length')) {
		return 1;
	}
	
	return undef;
}

sub input_converter {
	my ($self, $target) = @_;
	
	my $options = {
		input_name => $target,
		output_name => $self->qualified_name,
		must_not_delete => 1,	# never try to delete a constant
	};
	for my $x (qw(array_length string_length max_array_length max_string_length)) {
		if ($self->has($x)) {
			$options->{$x} = $self->{$x};
		}
	}
	
	return $self->type->input_converter($options);
}

sub output_converter {
	my ($self, $target) = @_;
	my ($self, $target) = @_;
	
	my $options = {
		input_name => $self->qualified_name,
		output_name => $target,
		must_not_delete => 1,	# never try to delete a constant
	};
	for my $x (qw(array_length string_length max_array_length max_string_length)) {
		if ($self->has($x)) {
			$options->{$x} = $self->{$x};
		}
	}
	
	return $self->type->output_converter($options);
}

sub generate {
	my ($self) = @_;
	
	my $name = $self->name;
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	my ($ctype_to_sv_defs, $ctype_to_sv_code, $ctype_to_sv_precode) 
		= $self->output_converter('RETVAL');
	
	my $fh = $self->package->xsh;
	
	print $fh <<CONST;
SV*
$name()
	CODE:
		RETVAL = newSV(0);
CONST
	
	for my $line (@$ctype_to_sv_defs, @$ctype_to_sv_code, @$ctype_to_sv_precode) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<CONST;
		dualize(RETVAL, "$name");
	OUTPUT:
		RETVAL

CONST
}

1;
