use Common::Constants;
use Perl::BaseObject;

package Perl::Constants;
use strict;
our @ISA = qw(Constants Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('constants')) {
		for my $c ($self->constants) {
			$c->generate;
		}
	}
}

package Perl::Constant;
use strict;
our @ISA = qw(Constant Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	my $name = $self->name;
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	print { $self->package->xsh } <<CONST;
SV*
$name()
	CODE:
		RETVAL = newSViv($name);
	OUTPUT:
		RETVAL

CONST
}

1;
