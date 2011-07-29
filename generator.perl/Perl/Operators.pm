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
	if ($type eq 'neg' or $type eq 'math' or $type eq 'mut') {
		$rettype = 'SV*';
	}
	elsif ($type eq 'cmp') {
		$rettype = 'bool';
	}
	
	my $fh = $self->package->xsh;
	
	print $fh <<OPERATOR;
$rettype
${cpp_class_name}::$fname(object, swap)
OPERATOR
	
	if ($type eq 'neg') {
		my $type_obj = $self->types->type("$cpp_class_name*");
		my $converter = $type_obj->output_converter({
			input_name => 'result',
			output_name => 'RETVAL',
		});
		print $fh <<CODE;
	INPUT:
		SV* object;	// don't try to convert it
		IV swap;
	OVERLOAD: $name
	CODE:
		$cpp_class_name* result;
//		why do these next two statements not work?
//		*result = -*THIS;
//		*result = -(*THIS);
//		but this workaround does
		$cpp_class_name holder;
		holder = *THIS;
		*result = -holder;
		RETVAL = newSV(0);
		$converter
CODE
	}
	elsif ($type eq 'cmp') {
		print $fh <<CODE;
	INPUT:
		$cpp_class_name object;
		IV swap;
	OVERLOAD: $name
	CODE:
		RETVAL = *THIS $name object;
CODE
	}
	elsif ($type eq 'math') {
		my $type_obj = $self->types->type("$cpp_class_name*");
		my $converter = $type_obj->output_converter({
			input_name => 'result',
			output_name => 'RETVAL',
		});
		print $fh <<CODE;
	INPUT:
		$cpp_class_name object;
		IV swap;
	OVERLOAD: $name
	CODE:
		$cpp_class_name* result;
		*result = *THIS $name object;
		RETVAL = newSV(0);
		$converter
CODE
	}
	elsif ($type eq 'mut') {
		my $type_obj = $self->types->type("$cpp_class_name*");
		my $converter = $type_obj->output_converter({
			input_name => 'THIS',
			output_name => 'RETVAL',
		});
		print $fh <<CODE;
	INPUT:
		$cpp_class_name object;
		IV swap;
	OVERLOAD: $name
	CODE:
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
