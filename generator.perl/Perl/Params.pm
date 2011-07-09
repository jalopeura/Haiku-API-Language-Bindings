use Common::Functions;
use Perl::BaseObject;

package Perl::Params;
use strict;
our @ISA = qw(BaseObject Perl::BaseObject);

sub new {
	my ($class, @params) = @_;
	
	my $self = bless {
		_params => {},
		cpp_input => [],
		perl_input => [],
		perl_output => [],
		perl_error => [],
	}, $class;
	
	$self->add(@params);
	
	return $self;
}

sub add {
	my ($self, @params) = @_;
	
	my @mod;
	for my $param (@params) {
		$self->{_params}{ $param->name } = $param;
		
		if ($param->isa('Return')) {
			$self->{cpp_output} = $param;
		}
		else {
			push @{ $self->{cpp_input} }, $param;
		}
		
		my $action = $param->action;
		if ($action eq 'input') {
			push @{ $self->{perl_input} }, $param;
		}
		elsif ($action eq 'output') {
			push @{ $self->{perl_output} }, $param;
		}
		elsif ($action eq 'error') {
			push @{ $self->{perl_error} }, $param;
		}
		elsif ($action=~/^(length|count)\[(.+?)\]$/) {
			push @mod, [ $1, $2, $param ];
		}
		else {
			die "Unsupported param action '$action'";
		}
	}
	
	for my $m (@mod) {
		my ($key, $name, $param) = @$m;
		$self->{_params}{$name}{$key} = $param;	
	}
}

# as_cpp_input gives the paramaters as used in a function definition
sub as_cpp_input {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_input;
	}
	
	return \@args;
}
sub as_cpp_parent_input {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->name;
	}
	
	return \@args;
}

# as_cpp_call gives the arguments ase used in a functioncall
sub as_cpp_call {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_call;
	}
	
	return \@args;
}

sub cpp_rettype {
	my ($self) = @_;
	if ($self->has('cpp_output')) {
		return $self->cpp_output->type;
	}
	return 'void';
}

sub as_xs_input {
	my ($self) = @_;
	
	my (@inputs, @input_defs);
	for my $param ($self->perl_input) {
		if ($param->has('default')) {
			push @inputs, '...';
			last;
		}
		my ($input, $input_def) = $param->as_xs_input;
		push @inputs, $input;
		push @input_defs, $input_def;
	}
	
	return (\@inputs, \@input_defs);
}

sub xs_error_code {
	my ($self) = @_;
	
	my @code;
	for my $param ($self->perl_error) {
		my $errname = $param->name;
		my $success = $param->success;
		my $varname = $self->module_name . '::Error';
		push @code,
			qq(if ($errname != $success) {),
			qq(	// this doesn't seem to be working...),
			qq(	error_sv = get_sv("!", 1);),
			qq(	sv_setiv(error_sv, (IV)error);),
			qq(	// ...so use this for now),
			qq(	error_sv = get_sv("$varname", 1);),
			qq(	sv_setiv(error_sv, (IV)error);),
			qq(	XSRETURN_UNDEF;),
			qq(});
	}
	
	return \@code;
}

sub as_xs_call {
	my ($self) = @_;
	
	my ($count, @defs, @puts);
	for my $param ($self->perl_input) {
		$count++;
		my ($def, $put) = $param->as_xs_call;
		push @defs, @$def;
		push @puts, @$put, '';	# empty string so we get a newline in the output
	}
	
	return ($count, \@defs, \@puts);
}

# assume typemap will take care of output(s); just return error(s)
# if typemap does not handle output(s), function object will deal with it
sub as_xs_init {
	my ($self) = @_;
	
	my (@preinits, @inits, @code);
	
	for my $param ($self->perl_error) {
		push @inits, $param->as_xs_init;
	}
	
	my $i = 0;
	for my $param ($self->perl_input) {
		$i++;
		if ($param->has('count')) {
			my $name = $param->name;
			my $type = $param->type;
			my $cname = $param->count->name;
			my $ctype = $param->count->type;
			push @preinits, "int count_$name;";
			push @inits, "$ctype $cname = count_$name;"
		}
		if ($param->has('default')) {
			my $name = $param->name;
			my $type = $param->type;
			my $def = $param->default;
			push @inits, "$type $name = $def;";
			
			$type = $self->types->type($type);
			my $n = $i+1;
			my $converter = $type->input_converter($name, "ST($i)");
			push @code,
				qq(if (items >= $n)),
				"\t" . $converter;
		}
	}
	
	return (\@preinits, \@inits, \@code);
}
		

package Perl::Argument;
use strict;
our @ISA = qw(Perl::BaseObject);

sub as_cpp_input {
	my ($self) = @_;
	my $arg = "$self->{type} $self->{name}";
	return $arg;
}

sub as_cpp_call {
	my ($self) = @_;
	my $arg = $self->name;
	if ($self->needs_deref) {
		$arg = "&$arg";
	}
	return $arg;
}

sub as_xs_input {
	my ($self) = @_;
	my $input = $self->name;
	my $input_def = "$self->{type} $self->{name};";
	return ($input, $input_def);
}

sub as_xs_init {
	my ($self) = @_;
	my $type = $self->type;
	if ($self->needs_deref) {
		$type=~s/\*//;
	}
	return (
		"$type $self->{name};",
		"SV* $self->{name}_sv;",
	);
}

sub as_xs_call {
	my ($self) = @_;
	
	my $name = $self->name;
	
	my $svname = $name . '_sv';
	my @defs = (qq(SV* $svname;));
	
	if ($self->{count}) {
		my $cname = $self->count->name;
		push @defs, qq(int count_$name = $cname;);
	}
	
	my $type = $self->types->type($self->type);
	my $converter = $type->output_converter($name, $svname);
	my @puts = (
		qq($svname = sv_newmortal();),
		$converter
	);
	
	if ($self->must_not_delete) {
		push @puts, 
			qq(must_not_delete_cpp_object($svname, true););
	}
	
	push @puts, qq(PUSHs($svname););
	
	return (\@defs, \@puts);
}

package Perl::Param;
use strict;
our @ISA = qw(Param Perl::Argument);

package Perl::Return;
use strict;
our @ISA = qw(Return Perl::Argument);

1;
