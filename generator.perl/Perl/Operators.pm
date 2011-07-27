use Common::Operators;
use Perl::BaseObject;

package Perl::Operators;
use strict;
our @ISA = qw(Operators Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('operators')) {
		for my $g ($self->operators) {
			$g->generate;
		}
	}
}

package Perl::Operator;
use strict;
our @ISA = qw(Operator Perl::BaseObject);

my %ops = (
	'neg' => { 
		name => 'neg',
		type => 'neg',	# negation
	},
	
	'==' => { 
		name => 'eq',
		type => 'cmp',	# comparison
	},
	'!=' => { 
		name => 'ne',
		type => 'cmp',	# comparison
	},
	
	'+' => { 
		name => 'add',
		type => 'math',	# mathematical
	},
	'-' => { 
		name => 'sub',
		type => 'math',	# mathematical
	},
	'&' => { 
		name => 'and',
		type => 'math',	# mathematical
	},
	'|' => { 
		name => 'or',
		type => 'math',	# mathematical
	},
	
	'+=' => { 
		name => 'iadd',
		type => 'mut',	# mutator
	},
	'-=' => { 
		name => 'isub',
		type => 'mut',	# mutator
	},
);

sub generate {
	my ($self) = @_;
	
	my $name = $self->name;
	
	$ops{$name} or die "Unsupported operator '$name'";
	
	my $cpp_class_name = $self->package->cpp_name;
	my $fname = "operator_$ops{$name}{name}";
	my $type = $ops{$name}{type};
	
	my $rettype;
	if ($type eq 'neg') {
		$rettype = $cpp_class_name;
	}
	elsif ($type eq 'cmp') {
		$rettype = 'bool';
	}
	if ($type eq 'math' or $type eq 'mut') {
		$rettype = 'SV*';
	}
	
	my $fh = $self->package->xsh;
	
	print $fh <<OPERATOR;
$rettype
${cpp_class_name}::$fname(object, swap)
	INPUT:
		$cpp_class_name object;
		IV swap;
	OVERLOAD: $name
	CODE:
OPERATOR
	
	if ($type eq 'neg') {
		print $fh "\t\tRETVAL = -(*THIS);\n";
	}
	elsif ($type eq 'cmp') {
		print $fh "\t\tRETVAL = *THIS $name object;\n";
	}
	elsif ($type eq 'math') {
		my $type_obj = $self->types->type($cpp_class_name);
		my $converter = $type_obj->output_converter('result', 'RETVAL');
		print $fh <<CODE;
		$cpp_class_name result;
		result = *THIS $name object;
		RETVAL = newSV(0);
		$converter
CODE
	}
	elsif ($type eq 'mut') {
		my $type_obj = $self->types->type("$cpp_class_name*");
		my $converter = $type_obj->output_converter('THIS', 'RETVAL');
		print $fh <<CODE;
		*THIS $name object;
		RETVAL = newSV(0);
		$converter
CODE
	}
	
	print $fh <<OPERATOR;
	OUTPUT:
		RETVAL

OPERATOR
}

1;
