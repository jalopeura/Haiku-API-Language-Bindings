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
	'char'    => 'T_IV',
	'short'   => 'T_IV',
	'int'     => 'T_IV',
	'long'    => 'T_IV',
	'unsignedchar'  => 'T_UV',
	'unsignedshort' => 'T_UV',
	'unsignedint'   => 'T_UV',
	'unsignedlong'  => 'T_UV',
	'wchar_t' => 'T_IV',
	'float'   => 'T_FLOAT',
	'double'  => 'T_DOUBLE',
	'longdouble'    => 'T_DOUBLE',
	'bool'    => 'T_BOOL',
	'char*'   => 'T_PV',
	'unsignedchar*' => 'T_PV',
	'constchar*'    => 'T_PV',
	'wchar_t*'      => 'T_PV',
	'void*'   => 'T_PV',
	'constvoid*'   => 'T_PV',
	'void'    => 'T_IV',	# should only be used with pass-as-pointer
	
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
	
	'NORM_OBJ'     => 'sv_setsv($arg, create_perl_object((void*)&$var, CLASS));',
	'NORM_OBJ_PTR' => 'sv_setsv($arg, create_perl_object((void*)$var, CLASS));',
	'RESP_OBJ'     => 'sv_setsv($arg, $var.perl_link_data->perl_object);',
	'RESP_OBJ_PTR' => 'sv_setsv($arg, $var->perl_link_data->perl_object);',
#	'NORM_OBJ'     => '$arg = create_perl_object((void*)&$var, CLASS);',
#	'NORM_OBJ_PTR' => '$arg = create_perl_object((void*)$var, CLASS);',
#	'RESP_OBJ'     => '$arg = $var.perl_link_data->perl_object;',
#	'RESP_OBJ_PTR' => '$arg = $var->perl_link_data->perl_object;',
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
			
			if (my $new_type = $self->{_typemap}{$name}) {			
				for my $x (qw(
					array_length max_array_length
					string_length max_string_length
				)) {
					next unless $type->has($x);
					$new_type->{$x} = $type->{$x};
				}
				return $new_type;
			}
		}
		
		(my $k = $basename)=~s/ //g;
		if ($builtins{$k}) {
			return new Perl::BuiltinType($name, $builtins{$k}, $perltypes{ $builtins{$k} });
		}
	}
	
	(my $k = $name)=~s/ //g;
	if ($builtins{$k}) {
		return new Perl::BuiltinType($name, $builtins{$k}, $perltypes{ $builtins{$k} });
	}
	
	die "Unrecognized type '$name'";
}

sub qualified_types {
	my ($self) = @_;
	
	my %ret;
	for my $type (@{ $self->{types} }) {
		my $name = $type->name;
		next unless $name=~/::/;
		$name=~s/^const\s+//;
		$name=~s/\*$//;
		$ret{$name}++;
	}
	return sort keys %ret;
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
		
		# namespaces need a qualified version and an unqualified version
		next unless $name=~/::/;
		$name=~s/\S+::([^:]+)$/$1/;
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

INPUT

RESP_OBJ
	$input_converters{RESP_OBJ}

RESP_OBJ_PTR
	$input_converters{RESP_OBJ_PTR}

NORM_OBJ
	$input_converters{NORM_OBJ}

NORM_OBJ_PTR
	$input_converters{NORM_OBJ_PTR}

OBJTYPES
	
	close OUT;
}

package Perl::Type;
use strict;
our @ISA = qw(Type Perl::BaseObject);

# convert Perl SV* to some C++ type
sub input_converter {
	my ($self, $options) = @_;
	
	if ($options->{array_length}) {
		return $self->array_input_converter($options);
	}
	
	my (@defs, @code, @postcode);
	my $arg = $options->{input_name};
	my $var = $options->{output_name};
	my ($pfx) = $arg=~/([^.>]+)$/;
	$pfx=~s/_sv$//; $pfx=~s/\W/_/g; $pfx=~s/_$//;
	
	my $len =  $options->{string_length};
	if (not $len and $self->has('string_length')) {
		$len = $self->string_length;
	}
	
	my $maxlen =  $options->{max_string_length};
	if (not $maxlen and $self->has('max_string_length')) {
		$maxlen = $self->max_string_length;
	}
	
	# strings with lengths need special processing
	if ($len and $len ne 'null-terminated') {
		$len=~s/SELF\./$options->{self_name}->/;
		my $ptr = $self->{perltype} eq 'T_PV';
		(my $base = $self->{name})=~s/const\s+//; $base=~s/\*$//;

		# malloc if necessary
		if ($options->{pass_as_pointer}) {
			push @code, "$var = ($self->{name}*)malloc($len);";
			push @postcode, "free((void*)$var);";
		}
		
		if ($ptr) {
			# non-constant lengths
			if ($options->{set_string_length}) {
				my $sv_length = "$pfx\_sv_length";
				push @defs, "STRLEN $sv_length;";
				push @code,
					"$var = ($self->{name})SvPV($arg, $sv_length);",
					"$len = $sv_length;",;
			}
			else {
				push @code, "$var = ($self->{name})SvPV_nolen($arg);";
			}
		}
		else {
			# non-constant lengths
			if ($options->{set_string_length}) {
				push @code, "memcpy((void*)&$var, (void*)SvPV($arg, $len), $len);";
			}
			else {
				push @code, "memcpy((void*)&$var, (void*)SvPV_nolen($arg), $len);";
			}
		}
		
		# not sure if this is necessary
#		if (
#			$options->{string_length} and
#			$len ne 'null-terminated' and
#			$base ne 'char'
#			) {
#			push @code, "$len /= sizeof($base)";
#		}
	}
	# maximum length (but can be null-terminated)
	elsif ($maxlen) {
		$maxlen=~s/SELF\./$options->{self_name}->/;
		my $ptr = $self->{perltype} eq 'T_PV';
		(my $base = $self->{name})=~s/const\s+//; $base=~s/\*$//;

		# malloc if necessary
		if ($options->{pass_as_pointer}) {
			push @code, "$var = ($self->{name}*)malloc($maxlen);";
			push @postcode, "free((void*)$var);";
		}
		
		my $sv_length = "$pfx\_sv_length";
		push @defs, "STRLEN $sv_length = SvCUR($arg);";
		
		# if the current length of the Perl string is longer than
		# the max length allowed, shorten the Perl string
		push @code,
			'',
			qq(if ($sv_length > $maxlen) {),
			qq(\tchar* last_char;),
			qq(\t$sv_length = $maxlen;),
			qq(\tSvCUR_set($arg, $sv_length);),
			qq(\tlast_char = SvEND($arg);	// pointer to last character),
			qq(\t*last_char = '\\0';),
			qq(}),
			'';
		
		if ($ptr) {
			push @code, "$var = ($self->{name})SvPV($arg, $sv_length);";
		}
		else {
			push @code, "memcpy((void*)&$var, (void*)SvPV($arg, $sv_length), $sv_length);";
		}
		
		if ($options->{set_string_length}) {
			push @code, qq(\t$maxlen = $sv_length);
		}	
	}
	elsif ($len eq 'null-terminated' and not $self->{name}=~/\*$/) {
		my $sv_length = "$pfx\_sv_length";
		push @defs, "STRLEN $sv_length;";
		push @code, "memcpy((void*)$var, (void*)SvPV($arg, $sv_length), $sv_length);";
	}
	else {
		my $converter = $Perl::Types::input_converters{ $self->perltype };
		
		# values for the eval
		my $type = $self->name;
		my $ntype = '$ntype';
		
		if ($self->has('target') and $options->{must_not_delete}) {
			push @code,
				"must_not_delete_cpp_object($options->{input_name}, true);";
		}
		
		my $ret = eval "qq($converter)" or die $@;
		
		push @code, $ret;
	}
	
	return (\@defs, \@code, \@postcode);
}

# convert Perl SV* containing an aref to C++ array of some type
sub array_input_converter {
	my ($self, $options) = @_;
	
	my (@defs, @code, @postcode);
	my $arg = $options->{input_name};
	my $var = $options->{output_name};
	
	my $array = "${arg}_av";
	my $cpp_item = "${var}[i]";
	my $perl_item = 'element_sv';
	my $none = $self->{name}=~/\*$/ ? 'NULL' : 0;
	$none or do {
		# an object but not via a pointer
		if ($self->has('target')) {
			undef $none;
		}
	};
	
	my $count = delete $options->{array_length};
	# I should make these constants instead of hard-coding them here
	$count=~s/SELF\./$options->{self_name}->/;

	# malloc if necessary
	if ($options->{pass_as_pointer}) {
		(my $base = $self->{name})=~s/const\s+//;
		push @code, "$var = ($self->{name}*)malloc($count * sizeof($base));";
		push @postcode, "free((void*)$var);";
	}
	
	$options->{input_name} = "*$perl_item";
	$options->{output_name} = $cpp_item;
	my ($item_defs, $item_code) = $self->input_converter($options);
	
	push @defs,
		"AV* $array;",
		@$item_defs;
	
	push @code, (
		"//Converting Perl arg '$arg' to C array '$var'",
		qq($array = (AV*)SvRV($arg);),
	);
	
	# non-constant lengths
	if ($options->{set_array_length}) {
		push @code, "$count = av_len($array) + 1;";
	}
	
	push @code, (
		qq(for (int i = 0; i < $count; i++) {),
		qq(\tSV** $perl_item = av_fetch($array, i, 0);),
		qq(\tif ($perl_item == NULL) {)
	);
	
	if (defined $none) {
		push @code, qq(\t\t$cpp_item = $none;);
	}
	else {
		push @code,
			qq(\t\t// should be setting this to some default),
			qq(\t\t// but neither 0 nor NULL is right);
	}
	
	push @code, (
		qq(\t\tcontinue;),
		"\t}",
		map({ "\t$_" } @$item_code),
		'}',
	);
	
	return (\@defs, \@code, \@postcode);
}

# convert some C++ type to Perl SV*
sub output_converter {
	my ($self, $options) = @_;
	
	if ($options->{array_length}) {
		return $self->array_output_converter($options);
	}
	
	my (@defs, @code, @precode);
	my $var = $options->{input_name};
	my $arg = $options->{output_name};
	my ($pfx) = $arg=~/(\w+)$/;
	$pfx=~s/_sv$//; $pfx=~s/\W/_/g; $pfx=~s/_$//;
	
	my $len =  $options->{string_length};
	if (not $len and $self->has('string_length')) {
		$len = $self->string_length;
	}
	
	my $maxlen =  $options->{max_string_length};
	if (not $maxlen and $self->has('max_string_length')) {
		$maxlen = $self->max_string_length;
	}
	
	# strings with lengths need special processing
	if ($len and $len ne 'null-terminated') {
		$len=~s/SELF\./$options->{self_name}->/;
		my $ptr = $self->{perltype} eq 'T_PV';
		(my $base = $self->{name})=~s/const\s+//; $base=~s/\*$//;
		
		# special case: char
		# (instead of char[] or char*)
		if ($len eq '1' and not $ptr) {
			$var = "&$var";
		}
		
		push @code,
			"$arg = newSVpvn((char*)$var, (STRLEN)$len);",
			"if (is_utf8_string((const U8*)$var, (STRLEN)$len)) {",
			"\tSvUTF8_on($arg);",
			'}';

		# malloc if necessary
		if ($options->{pass_as_pointer}) {
			push @precode, "$var = ($self->{name}*)malloc($len);";
			push @code, "free((void*)$var);";
		}
	}
	# maximum length (but can be null-terminated)
	elsif ($maxlen) {
		$maxlen=~s/SELF\./$options->{self_name}->/;
		my $ptr = $self->{perltype} eq 'T_PV';
		(my $base = $self->{name})=~s/const\s+//; $base=~s/\*$//;
		
		if ($base ne 'char' and not $ptr) {
			$len .= " * sizeof($base)";
		}
		
		# special case: char
		# (instead of char[] or char*)
		if ($len eq '1' and not $ptr) {
			$var = "&$var";
		}
		
		# if the no-length version (which ends at the first null) is longer
		# than the max length allowed , shorten the Perl string
		my $sv_length = "$pfx\_sv_length";
		push @defs, "STRLEN $sv_length;";
		push @code,
			"$arg = newSVpv((char*)$var, 0);	// 0 lets Perl calculate length",
			'',
			"$sv_length = SvCUR($arg);",
			qq(if ($sv_length > $maxlen) {),
			qq(\t$sv_length = $maxlen;),
			qq(\tSvCUR_set($arg, $sv_length);),
			qq(}),
			'';
		
		# check for utf8
		push @code, 
			"if (is_utf8_string((const U8*)$var, (STRLEN)$sv_length)) {",
			"\tSvUTF8_on($arg);",
			'}';

		# malloc if necessary
		if ($options->{pass_as_pointer}) {
			push @precode, "$var = ($self->{name}*)malloc($maxlen);";
			push @code, "free((void*)$var);";
		}
	}
	elsif ($len eq 'null-terminated' and not $self->{name}=~/\*$/) {
		my $sv_length = "$pfx\_sv_length";
		push @defs, "STRLEN $sv_length;";
		push @code,
			"$arg = newSVpv($var, 0);",
			"$sv_length = SvCUR($arg);",
			"if (is_utf8_string((const U8*)$var, (STRLEN)$sv_length)) {",
			"\tSvUTF8_on($arg);",
			'}';
	}
	# null-terminated strings and non-string types use default converters
	else {
		my $converter = $Perl::Types::output_converters{ $self->perltype };
		
		if ($options->{must_not_delete}) {
			$converter=~s/CLASS/CLASS, true/;
		}
		
		if ($self->has('target')) {
			$converter=~s/CLASS/"$self->{target}"/;
		}
		
		# values for the eval
		my $type = $self->name;
		my $ntype = '$ntype';
		
		my $ret = eval "qq($converter)" or die $@;
		
		push @code, $ret;
	}
	
	return (\@defs, \@code, \@precode);
}

# convert C++ array of some type to Perl SV* containing an aref
sub array_output_converter {
	my ($self, $options) = @_;
	
	my (@defs, @code, @precode);
	my $var = $options->{input_name};
	my $arg = $options->{output_name};
	
	my $array = "${arg}_av";
	my $cpp_item = "${var}[i]";
	my $perl_item = 'element_sv';
	
	my $count = delete $options->{array_length};
	# I should make these constants instead of hard-coding them here
	$count=~s/SELF\./$options->{self_name}->/;
	
	$options->{input_name} = $cpp_item;
	$options->{output_name} = $perl_item;
	my ($item_defs, $item_code) = $self->output_converter($options);
	
	push @defs,
		"AV* $array;",
		@$item_defs;
	
	push @code, (
		"//Converting C array '$var' to Perl arg '$arg'",
		qq($array = newAV();),
		qq(for (int i = 0; i < $count; i++) {),
		qq(\tSV* $perl_item = newSV(0);),
		map({ "\t$_" } @$item_code),
		qq(\tav_push($array, $perl_item);),
		'}',
		qq($arg = newRV_noinc((SV*) $array);),
	);
	
	return (\@defs, \@code, \@precode);
}

package Perl::BuiltinType;
use strict;
our @ISA = qw(Perl::Type);

sub new {
	my ($class, $name, $perltype, $svtype) = @_;
	(my $builtin = $name)=~s/const\s+//;	# allows for const versions of builtins
	if ($name eq 'enum') {
		$name = Perl::Types::ENUM_TYPE;
	}
	my $self = bless {
		name     => $name,
		builtin  => $builtin,
		perltype => $perltype,
		svtype   => $svtype,
	};
	return $self;
}

1;
