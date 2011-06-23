package Python::Types;
use strict;

# need to handle long double

# map builtin types to python tuple format items
our %builtins = (
	'char'    => 'b',
	'short'   => 'h',
	'int'     => 'i',
	'long'    => 'l',
	'unsignedchar'  => 'B',
	'unsignedshort' => 'H',
	'unsignedint'   => 'I',
	'unsignedlong'  => 'k',
	'wchar_t' => 'h',
	'float'   => 'f',
	'double'  => 'd',
	'longdouble'    => 'd',
	'bool'    => 'O',
	'char*'   => 's',
	'unsignedchar*' => 's',
	'constchar*'    => 's',
	'wchar_t*'      => 'u',
	'char**'  => 'O',
	'void*'   => 'O',
	
	'responder' => 'O',
	'object'    => 'O',
	'responder_ptr' => 'O',
	'object_ptr'    => 'O',
);

sub new {
	my ($class) = @_;
	my $self = bless {
		typemap => {},
		types => [],
		converters => {},
	}, $class;
	return $self;
}

sub register_type {
	my ($self, $type, $builtin, $target) = @_;
	
	# don't register an already registered type
	if ($self->{typemap}{$type}) {
		# but warn if mapped to something different
		if ($self->{typemap}{$type}[0] ne $builtin) {
			warn "Type '$type' already mapped to '$self->{typemap}{$type}[0]'; cannot remap to '$builtin'";
		}
		return;
	}
	
	$self->verify_builtin($type, $builtin);
	
	$self->{typemap}{$type} = [ $builtin, $target ];
	push @{ $self->{types} }, $type;
}

sub get_builtin {
	my ($self, $type) = @_;
	return @{ $self->{typemap}{$type} } if $self->{typemap}{$type};
	
	(my $t = $type)=~s/ //g;
	return ($type) if $builtins{$type};
	
	return ();
}

sub get_format_item {
	my ($self, $type) = @_;
#print "Getting format item for $type\n";
	(my $t = $type)=~s/ //g;
	my $item = $builtins{$t};
	unless ($item) {
		if (my $t = $self->{typemap}{$type}) {
			(my $builtin = $t->[0])=~s/ //g;
#print "Converted $type to $builtin\n";
			$item = $builtins{$builtin};
		}
	}
#print "Found item $item\n";
	return $item;
}

sub needs_deref {
	my ($self, $type) = @_;
}

sub verify_builtin {
	my ($self, $type, $builtin) = @_;
	(my $key = $builtin)=~s/\s//g;
	$builtins{$key} or warn "Type '$type' mapped to unsupported builtin type '$builtin'";
}

sub registered_type_count {
	my ($self) = @_;
	my $c = $#{ $self->{types} } + 1;
	return $c;
}

sub converter {
}

sub write_destructors {
	my ($self, $h_fh, $c_fh) = @_;
	
	my %seen;
	
	for my $type (@{ $self->{types} }) {
		my ($builtin, $target) = @{ $self->{typemap}{$type} };
		next unless $builtin=~/^(object|responder)/;
		next if $seen{$target};
		$seen{$target} = 1;
		
		my @name = split /\./, $target;
		my $fname = join('_', @name, 'DESTROY');
		
		$type=~/\*$/ or $type .= '*';
		
		print $h_fh qq(static void $fname(void* ptr);\n);
		
		print $c_fh <<DESTR;

static void $fname(void* ptr) {
	$type THIS = ($type)ptr;
	// here we need to add some code to make sure we're really allowed to delete this
    delete THIS;
    return;
}
DESTR
	}
	
	print $h_fh "\n";
	print $c_fh "\n";
}

sub write_typeobject_defs {
	my ($self, $fh) = @_;
	
	my %seen;
	for my $type (@{ $self->{types} }) {
		my ($builtin, $target) = @{ $self->{typemap}{$type} };
		next unless $target;
		
		$type=~s/\*$//;
		next if $seen{$type};
		
		$seen{$type} = 1;
		$target=~s/\./_/g; $target .= '_Object';
		print $fh <<DEF;
typedef struct {
    PyObject_HEAD
    $type* cpp_object;
	bool  can_delete_cpp_object;
} $target;

DEF
	}
}

1;

__END__

this file needs to parse the types file and store the data
it also needs to keep track of every encountered type and determine a match for it

