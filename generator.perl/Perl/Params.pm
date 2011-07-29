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
			# ignore void returns
			return if ($param->{type} eq 'void');
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

sub Xdefault_var_code {
	my ($self, $offset) = @_;
	
	$offset--;
	my @code;
	if ($self->has('cpp_input')) {
		for my $param ($self->cpp_input) {
			if ($param->action eq 'input') {
				$offset++;
				next unless $param->has('default');
				push @code,
					qq(if (items > $offset) {),
					map { "\t$_" } @{ $param->input_converter("ST($offset)") },
					qq(});
			}
		}
	}
	
	return \@code;
}

# as_cpp_call gives the arguments as used in a function call
sub as_cpp_call {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_call;
	}
	
	return \@args;
}

# as_cpp_funcdef gives the paramaters as used in a function definition
sub as_cpp_funcdef {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_funcdef;
	}
	
	return \@args;
}

# as_cpp_call gives the arguments as used in a parent function call
# (as part of a constructor def)
sub as_cpp_parent_call {
	my ($self) = @_;
	
	my @args;
	for my $param ($self->cpp_input) {
		push @args, $param->as_cpp_parent_call;
	}
	
	return \@args;
}

sub cpp_rettype {
	my ($self) = @_;
	if ($self->has('cpp_output')) {
		return $self->cpp_output->type_name;
	}
	return 'void';
}
		

package Perl::Argument;
use strict;
our @ISA = qw(Perl::BaseObject);

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
	my ($self, $target, $modifiers) = @_;
	
	my $options = {
		output_name => $self->name,
		input_name => $target,
	};
	if ($modifiers->{suffix}) {
		$options->{input_name} .= delete $modifiers->{suffix};
	}
	for my $x (keys %$modifiers) {
		$options->{$x} = $modifiers->{$x};
	}
	for my $x (qw(array_length string_length)) {
		if ($self->has($x)) {
			$options->{$x} = $self->{$x};
		}
	}
	
	return $self->type->input_converter($options);
}

sub output_converter {
	my ($self, $target, $modifiers) = @_;
	
	my $options = {
		input_name => $self->name,
		output_name => $target,
		must_not_delete => $self->must_not_delete,
	};
	if ($modifiers->{suffix}) {
		$options->{output_name} .= $modifiers->{suffix};
	}
	for my $x (qw(array_length string_length)) {
		if ($self->has($x)) {
			$options->{$x} = $self->{$x};
		}
	}
	
	return $self->type->output_converter($options);
}

sub as_cpp_def {
	my ($self) = @_;
	my $type = $self->type->name;
	if ($self->has('array_length') and $self->pass_as_pointer) {
		$type .= '*'
	}
	my $arg = "$type $self->{name}";
	if ($self->has('default')) {
		$arg .= " = $self->{default}";
	}
	$arg .= ';';
	return $arg;
}

sub as_cpp_call {
	my ($self) = @_;
	my $arg = $self->name;
	if (
		$self->pass_as_pointer and
		not ($self->has('array_length') or $self->has('string_length'))
		) {
		$arg = "&$arg";
	}
	return $arg;
}

sub as_cpp_funcdef {
	my ($self) = @_;
	my $type = $self->{type_name};
	if ($self->pass_as_pointer) {
		$type .= '*';
	}
	my $arg = "$type $self->{name}";
	return $arg;
}

sub as_cpp_parent_call {
	my ($self) = @_;
	return $self->name;
}

sub xs_error_code {
	my ($self) = @_;
	
	my $errname = $self->name;
	my $success = $self->success;
	my $varname = $self->module_name . '::Error';
	my @code = (
		qq(if ($errname != $success) {),
		qq(	// this doesn't seem to be working...),
		qq(	error_sv = get_sv("!", 1);),
		qq(	sv_setiv(error_sv, (IV)$errname);),
		qq(	// ...so use this for now),
		qq(	error_sv = get_sv("$varname", 1);),
		qq(	sv_setiv(error_sv, (IV)$errname);),
		qq(	XSRETURN_UNDEF;),
		qq(}),
	);
		
	return @code;
}

package Perl::Param;
use strict;
our @ISA = qw(Param Perl::Argument);

package Perl::Return;
use strict;
our @ISA = qw(Return Perl::Argument);

1;
