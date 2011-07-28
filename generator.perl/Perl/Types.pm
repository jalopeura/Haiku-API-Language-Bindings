use Common::Types;
use Perl::BaseObject;

package Perl::Types;
use strict;
our @ISA = qw(Types Perl::BaseObject);

use constant ENUM_TYPE => 'int';

# need to handle long double
# map builtin types to perl types

# specs say:
# char  >=  8
# short >= 16; short >= char
# int   >= 16; int >= short
# long  >= 32; long >= int;
our %builtins = (
	'char'    => 'STRING',
	'intchar' => 'T_IV',
	'short'   => 'T_IV',
	'int'     => 'T_IV',
	'long'    => 'T_IV',
	'unsignedchar'  => 'T_U_CHAR',
	'unsignedshort' => 'T_UV',
	'unsignedint'   => 'T_UV',
	'unsignedlong'  => 'T_UV',
	'wchar_t' => 'WSTRING',
	'float'   => 'T_FLOAT',
	'double'  => 'T_DOUBLE',
	'longdouble'    => 'T_DOUBLE',
	'bool'    => 'T_BOOL',
	'char*'   => 'T_PV',
	'unsignedchar*' => 'T_PV',
	'constchar*'    => 'T_PV',
	'wchar_t*'      => 'T_PV',
	'char**'  => 'CHARARRAY',
	'void*'   => 'T_PTR',
	'constvoid*'   => 'T_PV',
	
	'responder' => 'RESP_OBJ',
	'object'    => 'NORM_OBJ',
	'responder_ptr' => 'RESP_OBJ_PTR',
	'object_ptr'    => 'NORM_OBJ_PTR',
);
#$builtins{enum} ||= $builtins{ENUM_TYPE};	# why doesn't this work?
my $k = ENUM_TYPE;
$builtins{enum} ||= $builtins{$k};

# map perl types to SV types
our %perltypes = (
	'T_CHAR'   => 'IV',
	'T_IV'     => 'IV',
	'T_BOOL'   => 'IV',
	
	'T_U_CHAR' => 'UV',
	'T_UV'     => 'UV',
	
	'T_FLOAT'  => 'NV',
	'T_DOUBLE' => 'NV',
	
	'T_PV'     => 'PV',
	'CHARARRAY' => 'PV',
	'STRING'   => 'PV',
	'WSTRING'  => 'PV',
	'T_PTR'    => 'PV',
	
	# how to deal with objects?
);

# how to convert from Perl to C++
our %input_converters = (
	'T_CHAR'   => '$var = ($type)*SvPV_nolen($arg);',
	'T_IV'     => '$var = ($type)SvIV($arg);',
	'T_BOOL'   => '$var = SvTRUE($arg);',
	
	'T_U_CHAR' => '$var = ($type)SvUV($arg);',
	'T_UV'     => '$var = ($type)SvUV($arg);',
	
	'T_FLOAT'  => '$var = ($type)SvNV($arg);',
	'T_DOUBLE' => '$var = ($type)SvNV($arg);',
	
	'T_PV'     => '$var = ($type)SvPV_nolen($arg);',
	'CHARARRAY' => '$var = Aref2CharArray($arg, count_$var);',
	'STRING'    => 'Scalar2Char($arg, (void*)&$var, LENGTH, sizeof(char));',
	'WSTRING'   => 'Scalar2Char($arg, (void*)&$var, LENGTH, sizeof(wchar_t));',
	'T_PTR'    => '$var = INT2PTR($type,SvIV($arg));',
	
	'NORM_OBJ'     => '$var = *($type*)get_cpp_object($arg);',
	'NORM_OBJ_PTR' => '$var = ($type)get_cpp_object($arg);',
	'RESP_OBJ'     => '$var = *($type*)get_cpp_object($arg);',
	'RESP_OBJ_PTR' => '$var = ($type)get_cpp_object($arg);',
);

# now to convert from C++ to Perl
our %output_converters = (
	'T_CHAR'   => 'sv_setpvn($arg, (char *)&$var, 1);',
	'T_IV'     => 'sv_setiv($arg, (IV)$var);',
	'T_BOOL'   => '$arg = boolSV($var);',
	
	'T_U_CHAR' => 'sv_setuv($arg, (UV)$var);',
	'T_UV'     => 'sv_setuv($arg, (UV)$var);',
	
	'T_FLOAT'  => 'sv_setnv($arg, (double)$var);',
	'T_DOUBLE' => 'sv_setnv($arg, (double)$var);',
	
	'T_PV'     => 'sv_setpv((SV*)$arg, $var);',
	'CHARARRAY' => '$arg = CharArray2Aref($var, count_$var);',
	'STRING'   => '$arg = Char2Scalar(&$var, LENGTH, sizeof(char));',
	'WSTRING'  => '$arg = Char2Scalar(&$var, LENGTH, sizeof(wchar_t));',
	'T_PTR'    => 'sv_setiv($arg, PTR2IV($var));',
	
	'NORM_OBJ'     => 'sv_setsv($arg, create_perl_object((void*)&$var, CLASS));',
	'NORM_OBJ_PTR' => 'sv_setsv($arg, create_perl_object((void*)$var, CLASS));',
#	'RESP_OBJ'     => '$arg = $var.perl_link_data->perl_object;',
#	'RESP_OBJ_PTR' => '$arg = $var->perl_link_data->perl_object;',
	'RESP_OBJ'     => 'sv_setsv($arg, $var.perl_link_data->perl_object);',
	'RESP_OBJ_PTR' => 'sv_setsv($arg, $var->perl_link_data->perl_object);',
);

sub create_empty {
	my ($class) = @_;
	return bless { types => [] }, $class;
}

sub finalize_upgrade {
	my ($self) = @_;
	
	$self->{_typemap} = {};
	$self->{types} ||= [];
	for my $type ($self->types) {
		my $name = $type->name;
		my $builtin = $type->builtin;
		$self->verify_builtin($name, $builtin);
		$self->{_typemap}{$name} = $type;
		
		$builtin=~s/ //g;
		my $perltype = $builtins{$builtin} or
			warn "Type '$name' mapped to unsupported builtin type '$builtin'";
#		my $perltype;
#		$perltype = $builtins{$builtin} or do {
#			$builtin=~s/^const//;
#			$perltype = $builtins{$builtin} or
#				warn "Type '$name' mapped to unsupported builtin type '$builtin'";
#		};
			
		$type->{perltype} = $perltype;
		$type->{svtype} = $perltypes{$perltype};
	}
}

sub register_type {
	my ($self, $name, $builtin, $target) = @_;
#print "Registering type $type/$builtin/$target\n";
	
#	$type=~s/([^\s*])*/$1 */;	# xsubpp wants this space in the typemap
	
	# don't register an already registered type
	if (my $type = $self->{_typemap}{$name}) {
		# but warn if mapped to something different
		if ($type->builtin ne $builtin) {
			warn "Type '$name' already mapped to '$type->{builtin}'; cannot remap to '$builtin'";
		}
		return;
	}
	
	my $type = bless {
		name => $name,
		builtin => $builtin,
	}, 'Perl::Type';
	
	if ($target) {
		$type->{target} = $target;
	}
	
	$builtin=~s/ //g;
	my $perltype = $builtins{$builtin} or
		warn "Type '$type' mapped to unsupported builtin type '$builtin'";
		
	$type->{perltype} = $perltype;
	$type->{svtype} = $perltypes{$perltype};
	
	$self->{_typemap}{$name} = $type;
	push @{ $self->{types} }, $type;
}

sub verify_builtin {
	my ($self, $type, $builtin) = @_;
	(my $key = $builtin)=~s/\s//g;
}

sub registered_type_count {
	my ($self) = @_;
	if ($self->{types}) {
		my $c = $#{ $self->{types} } + 1;
		return $c;
	}
	return 0;
}

sub type {
	my ($self, $name) = @_;
	return $self->{_typemap}{$name} if $self->{_typemap}{$name};
	
	# copy base types for const types
	if ($name=~/^const\s/) {
		(my $basename = $name)=~s/^const\s+//;
		if (my $type = $self->{_typemap}{$basename}) {
			my $target;
			if ($type->has('target')) {
				$target = $type->target;
			}
			$self->register_type($name, $type->builtin, $target);
			return $self->{_typemap}{$name} if $self->{_typemap}{$name};
		}
	}
	(my $k = $name)=~s/ //g;
	if ($builtins{$k}) {
		return new Perl::BuiltinType($name, $builtins{$k}, $perltypes{ $builtins{$k} });
	}
	
	die "Unrecognized type '$name'";
}

sub write_typemap_file {
	my ($self, $filename) = @_;
	
	open OUT, ">$filename" or die "Unable to create file '$filename': $!";
	
	# write an intro comment
	print OUT <<INTRO;
#
#Automatically generated file
#
	
TYPEMAP
INTRO
	
	# add char** to force override of builtin
	for my $type (@{ $self->{types} }) {
		my $name = $type->name;
		(my $key = $type->builtin)=~s/\s//g;;
		my $equiv = $builtins{$key};
		print OUT "$name\t\t$equiv\n";
	}
	# force override of char**
	print OUT "char**\t\tCHARARRAY\n";
	print OUT "\n";
	
	
	# in addition to the builtin types, we have some others:
	# a responder C++ object, which keeps a reference to its Perl object
	# a regular C++ object, for which a Perl object must be created
	
	# output section: how C++ types are turned into Perl types
	# input section: how Perl types are turned into C++ types
	print OUT <<OBJTYPES;
OUTPUT

RESP_OBJ
	$output_converters{RESP_OBJ}

RESP_OBJ_PTR
	$output_converters{RESP_OBJ_PTR}

NORM_OBJ
	$output_converters{NORM_OBJ}

NORM_OBJ_PTR
	$output_converters{NORM_OBJ_PTR}

CHARARRAY
	$output_converters{CHARARRAY}

STRING
	$output_converters{STRING}

INPUT

RESP_OBJ
	$input_converters{RESP_OBJ}

RESP_OBJ_PTR
	$input_converters{RESP_OBJ_PTR}

NORM_OBJ
	$input_converters{NORM_OBJ}

NORM_OBJ_PTR
	$input_converters{NORM_OBJ_PTR}

CHARARRAY
	$input_converters{CHARARRAY}

STRING
	$input_converters{STRING}

OBJTYPES
	
	close OUT;
}

package Perl::Type;
use strict;
our @ISA = qw(Type Perl::BaseObject);

sub input_converter {
	my ($self, $var, $arg, $repeat) = @_;
	my $converter = $Perl::Types::input_converters{ $self->perltype };
	
	# values for the eval
	my $type = $self->name;
	my $ntype = '$ntype';
	
	my $ret = eval "qq($converter)" or die $@;
	
	if ($self->builtin eq 'char') {
		my $length = $self->has('repeat') ? $self->repeat : 1;
		$ret=~s/LENGTH/$length/;
	}
#print "Input converter for $self = $converter (with var=$var and arg=$arg); result was $ret\n";
#print "Called from ", join(':::', caller), "\n";
	return $ret;
}

sub array_input_converter {
	my ($self, $var, $arg, $repeat) = @_;
	
	my $array = "${arg}_av";
	my $cpp_item = "${var}[i]";
	my $perl_item = 'element_sv';
	my $none = $self->{name}=~/\*$/ ? 'NULL' : 0;
	
	my @ret = (
		"//Converting Perl arg '$arg' to C array '$var'",
		qq(AV* $array;),
		qq(SV** $perl_item;),
		qq($array = (AV*)SvRV($arg);),
		qq(for (int i = 0; i < $repeat; i++) {),
		qq(\t$perl_item = av_fetch($array, i, 0);),
		qq(\tif ($perl_item == NULL) {),
		qq(\t\t//$cpp_item = $none;	// need to fix this),
		qq(\t\tcontinue;),
		"\t}",
		"\t" . $self->input_converter($cpp_item, "*$perl_item"),
		'}',
	);
	
	return \@ret;
}

sub output_converter {
	my ($self, $var, $arg, $must_not_delete) = @_;
	my $converter = $Perl::Types::output_converters{ $self->perltype };
	
	# values for the eval
	my $type = $self->name;
	my $ntype = '$ntype';
	
	my $ret = eval "qq($converter)" or die "$@ ($self->{name}, $self->{perltype}, $converter)" . join(':::', caller);
	
	if ($self->builtin eq 'char') {
		my $length = $self->has('repeat') ? $self->repeat : 1;
		$ret=~s/LENGTH/$length/;
	}
	
	if ($must_not_delete) {
		$ret=~s/CLASS/CLASS, true/;
	}
	
	if ($self->has('target')) {
		$ret=~s/CLASS/"$self->{target}"/;
	}
	
#print "Output converter for $self = $converter (with var=$var and arg=$arg); result was $ret\n";
#print "Called from ", join(':::', caller), "\n";
	return $ret;
}

sub array_output_converter {
	my ($self, $var, $arg, $repeat, $must_not_delete) = @_;
	
	my $array = "${arg}_av";
	my $cpp_item = "${var}[i]";
	my $perl_item = 'element_sv';
	
	my @ret = (
		"//Converting C array '$var' to Perl arg '$arg'",
		qq(AV* $array;),
		qq(SV* $perl_item;),
		qq($array = newAV();),
		qq(for (int i = 0; i < $repeat; i++) {),
		qq(\t$perl_item = newSV(0);),
		"\t" . $self->output_converter($cpp_item, $perl_item, $must_not_delete),
		qq(\tav_push($array, element_sv);),
		'}',
		qq($arg = newRV_noinc((SV*) $array);),
	);
	
	return \@ret;
}

package Perl::BuiltinType;
use strict;
our @ISA = qw(Perl::Type);

sub new {
	my ($class, $name, $perltype, $svtype) = @_;
	if ($name eq 'intchar') {
		$name = 'char';
	}
	if ($name eq 'enum') {
		$name = Perl::Types::ENUM_TYPE;
	}
	my $self = bless {
		name     => $name,
		builtin  => $name,
		perltype => $perltype,
		svtype   => $svtype,
	};
	return $self;
}

1;
