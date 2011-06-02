package Perl::Types;
use strict;

# need to handle long double

our %builtins = (
	'char'    => 'T_CHAR',
	'short'   => 'T_IV',
	'int'     => 'T_IV',
	'long'    => 'T_IV',
	'unsignedchar'  => 'T_U_CHAR',
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
	'char**'  => 'T_PACKEDARRAY',
	'void*'   => 'T_PTR',
	
	'responder' => 'RESP_OBJ',
	'object'    => 'NORM_OBJ',
	'responder_ptr' => 'RESP_OBJ_PTR',
	'object_ptr'    => 'NORM_OBJ_PTR',
);

our %perltypes = (
	'T_CHAR'   => 'IV',
	'T_IV'     => 'IV',
	'T_BOOL'   => 'IV',
	
	'T_U_CHAR' => 'UV',
	'T_UV'     => 'UV',
	
	'T_FLOAT'  => 'NV',
	'T_DOUBLE' => 'NV',
	
	'T_PV'     => 'PV',
	'T_PACKEDARRAY' => 'PV',
	'T_PTR'    => 'PV',
	
	# how to deal with objects?
);

sub new {
	my ($class) = @_;
	my $self = bless {
		typemap => {},
		types => [],
	}, $class;
	return $self;
}

sub register_type {
	my ($self, $type, $equiv, $target) = @_;
	
#	$type=~s/([^\s*])*/$1 */;	# xsubpp wants this space in the typemap
	
	# don't register an already registered type
	if ($self->{typemap}{$type}) {
		# but warn if mapped to something different
		if ($self->{typemap}{$type}[0] ne $equiv) {
			warn "Type '$type' already mapped to '$self->{typemap}{$type}[0]'; cannot remap to '$equiv'";
		}
		return;
	}
	
	$self->verify_builtin($type, $equiv);
	
	$self->{typemap}{$type} = [ $equiv, $target ];
	push @{ $self->{types} }, $type;
}

sub get_builtin {
	my ($self, $type) = @_;
	return @{ $self->{typemap}{$type} } if $self->{typemap}{$type};
	return ();
}

sub get_perl_type {
	my ($self, $type) = @_;
	my $pt = $builtins{$type};
	unless ($pt) {
		if (my $t = $self->{typemap}{$type}) {
			(my $bt = $t->[0])=~s/ //g;
			$pt = $builtins{$bt};
		}
	}
	return $perltypes{$pt};
}

sub verify_builtin {
	my ($self, $type, $builtin) = @_;
	(my $key = $builtin)=~s/\s//g;
	$builtins{$key} or warn "Type '$type' mapped to unsupported builtin type '$builtin'";
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
	
	for my $type (@{ $self->{types} }) {
		(my $key = $self->{typemap}{$type}[0])=~s/\s//g;;
		my $equiv = $builtins{$key};
		print OUT "$type\t\t$equiv\n";
	}
	print OUT "\n";
	
	# in addition to the builtin types, we have some others:
	# a responder C++ object, which keeps a reference to its Perl object
	# a regular C++ object, for which a Perl object must be created
	
	# output section: how C++ types are turned into Perl types
	# input section: how Perl types are turned into C++ types
	print OUT <<OBJTYPES;
OUTPUT

RESP_OBJ
	sv_setsv(\$arg, \$var.perl_obj);

RESP_OBJ_PTR
	sv_setsv(\$arg, \$var->perl_obj);

NORM_OBJ
	sv_setsv(\$arg, create_perl_object((IV)&\$var, CLASS, 1));

NORM_OBJ_PTR
	sv_setsv(\$arg, create_perl_object((IV)\$var, CLASS, 1));

INPUT

RESP_OBJ
	\$type* \${var}_holder = (\$type*)extract_cpp_object(\$arg);
	\$var = *\${var}_holder;	// not sure this will work

RESP_OBJ_PTR
	\$var = (\$type)extract_cpp_object(\$arg);

NORM_OBJ
	\$type* \${var}_holder = (\$type*)extract_cpp_object(\$arg);
	\$var = *\${var}_holder;	// not sure this will work

NORM_OBJ_PTR
	\$var = (\$type)extract_cpp_object(\$arg);

OBJTYPES
	
	close OUT;
}

1;

__END__

this file needs to parse the types file and store the data
it also needs to keep track of every encountered type and determine a match for it

