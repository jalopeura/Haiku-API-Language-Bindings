use Common::Functions;
use Python::BaseObject;
use Python::Constructor;
use Python::Destructor;
use Python::Method;
use Python::Event;
use Python::Static;
use Python::Plain;
use Python::Params;

package Python::Functions;
use strict;
our @ISA = qw(Functions Python::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('constructors')) {
		for my $c ($self->constructors) {
			$c->generate;
		}
	}
	
	if ($self->has('destructor')) {
		$self->destructor->generate;
	}
	
	if ($self->has('methods')) {
		for my $m ($self->methods) {
			$m->generate;
		}
	}
	
	if ($self->has('events')) {
		for my $e ($self->events) {
			$e->generate;
		}
	}
	
	if ($self->has('statics')) {
		for my $s ($self->statics) {
			$s->generate;
		}
	}
	
	if ($self->has('plains')) {
		for my $p ($self->plains) {
			$p->generate;
		}
	}
}

# convenience package for inheritance
package Python::Function;
use strict;
our @ISA = qw(Python::BaseObject);

sub finalize_upgrade {
	my ($self) = @_;
	
	if ($self->has('params')) {
		$self->{params} = new Python::Params($self->params);
	}
	else {
		$self->{params} = new Python::Params;
	}
	
	if ($self->has('return')) {
		$self->{params} ||= new Python::Params();
		$self->params->add($self->return);
	}
}

sub generate {
	my ($self) = @_;
	
	$self->generate_cc;
	
	if ($self->class->is_responder) {
		$self->generate_h;
		$self->generate_cpp;
	}
	else {
		$self->generate_py;	# responders don't generate PY functions
	}
}

sub generate_py {}	# nothing to do

sub generate_cc {
	my ($self) = @_;
	(my $python_object_prefix = $self->python_class_name)=~s/\./_/g;
	
	my %options = (
		name    => "${python_object_prefix}_" . $self->name,
		rettype => 'PyObject*',
		code    => [],
		arg_input => 'PyObject* python_args',
	);
	
	if ($self->has('overload_name')) {
		$options{name} .= $self->overload_name;
	}
	
	(my $args, $options{input_defs}, my $code) =
		$self->params->as_input_from_python;
	
	if ($args) {
		push @{ $options{code} },
			qq(PyArg_ParseTuple(python_args, $args););
		
		if (@$code) {
			push @{ $options{code} }, @$code, '';
		}
	}
	
	if ($self->params->has('python_error')) {
		($options{error_defs}, $options{error_code}) = $self->params->as_python_error;
	}
	
	# no code is generated; a descendant class is expected to implement
	# its generate_cc_function to add code and make necessary changes to
	# other options
	
	$self->generate_cc_function(\%options);
}

sub generate_cc_function {
	my ($self, $options) = @_;
	
	my $fh = $self->class->cch;
	
	if ($options->{comment}) {
		print $fh $options->{comment};
	}
	
	print $fh <<DEF;
//static $options->{rettype} $options->{name}($options->{input});
static $options->{rettype} $options->{name}($options->{input}) {
DEF
	
	if ($options->{input_defs} and @{ $options->{input_defs} }) {
		print $fh "\t// defs\n";
		print $fh map { "\t$_\n" } @{ $options->{input_defs} };
		print $fh "\t\n";
	}
	if ($options->{error_defs} and @{ $options->{error_defs} }) {
		print $fh "\t// error defs\n";
		print $fh map { "\t$_\n" } @{ $options->{error_defs} };
		print $fh "\t\n";
	}
	
	if ($options->{code} and @{ $options->{code} }) {
		print $fh map { "\t$_\n" } @{ $options->{code} };
	}
	
	if ($options->{error_code} and @{ $options->{code} }) {
		print $fh "\t\n";
		print $fh map { "\t$_\n" } @{ $options->{error_code} };
	}
	
	if ($options->{return_code} and @{ $options->{return_code} }) {
		print $fh "\t\n";
		print $fh map { "\t$_\n" } @{ $options->{return_code} };
	}
	
	print $fh "}\n\n";
}

1;
