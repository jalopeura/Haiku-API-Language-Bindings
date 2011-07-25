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
		
		my $perl_class_name = $self->package->perl_name;
		(my $nil = $self->module_name)=~s/:/_/g;
		$nil = 'XS_' . $nil . '_nil';
		
		print { $self->package->xsh } <<OVERLOAD;
# xsubpp only enables overloaded operators for the initial module; additional
# modules are out of luck unless they roll their own, so that's what we do
# ($nil defined automatically by xsubpp)
BOOT:
	sv_setsv(
		get_sv("${perl_class_name}::()", TRUE),
		&PL_sv_yes	// so we don't get fallback errors
	);
    newXS("${perl_class_name}::()", $nil, file);

OVERLOAD
		
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
	
	if ($type ne 'neg') {
		print $fh <<OPERATOR;
	$cpp_class_name object;
	IV swap;
OPERATOR
	}
#	if ($type ne 'neg') {
#		print $fh <<OPERATOR;
#	INPUT:
#		$cpp_class_name object;
#		IV swap;
#OPERATOR
#	}
	
	print $fh <<OPERATOR;
	OVERLOAD: $name
	CODE:
OPERATOR
	
	if ($type eq 'cmp') {
		print $fh "\t\tRETVAL = *THIS $name object;\n";
	}
	else {
		my $type_obj = $self->types->type("$cpp_class_name*");
		my $converter = $type_obj->output_converter('result', 'RETVAL');
		
		if ($type eq 'neg') {
			print $fh <<CODE;
		$cpp_class_name* result = new $cpp_class_name();
		*result = -(*THIS);
CODE
		}
		elsif ($type eq 'math') {
			print $fh <<CODE;
		$cpp_class_name* result = new $cpp_class_name();
		*result = *THIS $name object;
CODE
		}
		elsif ($type eq 'mut') {
			print $fh "\t\t*THIS $name object;\n";
			$converter=~s/result/THIS/;
		}
		
		print $fh <<CONVERT;
		RETVAL = newSV(0);
		$converter
CONVERT
	}
	
	print $fh <<OPERATOR;
	OUTPUT:
		RETVAL

OPERATOR
}

1;
