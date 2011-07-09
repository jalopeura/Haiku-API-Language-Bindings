use Common::Functions;
use Perl::BaseObject;
use Perl::Constructor;
use Perl::Destructor;
use Perl::Method;
use Perl::Event;
use Perl::Static;
use Perl::Plain;
use Perl::Params;

package Perl::Functions;
use strict;
our @ISA = qw(Functions Perl::BaseObject);

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
package Perl::Function;
use strict;
our @ISA = qw(Perl::BaseObject);

sub finalize_upgrade {
	my ($self) = @_;
	
	if ($self->has('params')) {
		$self->{params} = new Perl::Params($self->params);
	}
	else {
		$self->{params} = new Perl::Params;
	}
	
	if ($self->has('return')) {
		$self->{params} ||= new Perl::Params();
		$self->params->add($self->return);
	}
}

sub generate {
	my ($self) = @_;
	
	$self->generate_xs;
	
	if ($self->package->is_responder) {
		$self->generate_h;
		$self->generate_cpp;
	}
	else {
		$self->generate_pm;	# responders don't generate PM function
	}
}

sub generate_pm {
	my ($self) = @_;
	
	my $name = $self->name;
	if ($self->has('overload_name')) {
		$name .= $self->overload_name;
	}
	my $perl_class_name = $self->perl_class_name;
	
	print { $self->package->pmh } <<POD;
#
# POD for ${perl_class_name}::$name
#

POD
}

sub generate_xs {
	my ($self) = @_;
	
	my %options = (
		name    => $self->name,
		rettype => $self->params->cpp_rettype,
	);
	
	($options{input}, $options{input_defs}) = $self->params->as_xs_input;
	
	($options{preinit}, $options{init}, $options{code}) = $self->params->as_xs_init;
	
	if ($self->has('overload_name')) {
		$options{name} .= $self->overload_name;
	}
	
	if ($self->params->has('perl_error')) {
		push @{ $options{error_code} }, @{ $self->params->xs_error_code };
	}
	
	# no code is generated; a descendant class is expected to implement
	# its generate_xs_function to add code and make necessary changes to
	# other options
	
	$self->generate_xs_function(\%options);
}

sub generate_xs_function {
	my ($self, $options) = @_;
	
	my $fh = $self->package->xsh;
	
	if ($options->{comment}) {
		print $fh $options->{comment};
	}
	
	my $input = join(', ', @{ $options->{input} });
	
	print $fh <<DEF;
$options->{rettype}
$options->{name}($input)
DEF
	
	if ($options->{preinit} and @{ $options->{preinit} }) {
		print $fh "\tPREINIT:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{preinit} };
	}
	
	if ($options->{input_defs} and @{ $options->{input_defs} }) {
		print $fh "\tINPUT:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{input_defs} };
	}
	
	if ($options->{init} and @{ $options->{init} }) {
		print $fh "\tINIT:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{init} };
	}
	
	if ($options->{code} and @{ $options->{code} }) {
		print $fh "\tCODE:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{code} };
	}
	
	if ($options->{error_code} and @{ $options->{code} }) {
		print $fh "\t\t\n";
		print $fh map { "\t\t$_\n" } @{ $options->{error_code} };
	}
	
	if ($options->{rettype} ne 'void') {
		print $fh <<OUT;
	OUTPUT:
		RETVAL
OUT
	}
	
	print $fh "\n";
}

1;
