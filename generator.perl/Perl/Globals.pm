use Common::Globals;
use Perl::BaseObject;

package Perl::Globals;
use strict;
our @ISA = qw(Globals Perl::BaseObject);

sub generate {
	my ($self) = @_;
	
	if ($self->has('globals')) {
		for my $g ($self->globals) {
			$g->generate;
		}
	}
}

package Perl::Global;
use strict;
our @ISA = qw(Global Perl::Constant);

# this code is the same as Constant; perhaps should alter it to reuse
sub Xgenerate {
	my ($self) = @_;
	
	my $name = $self->name;
	my $cpp_class_name = $self->package->cpp_name;
	my $perl_class_name = $self->package->perl_name;
	my $perl_module_name = $self->module_name;
	
	my $ctype_to_sv = $self->output_converter('RETVAL');
	
	print { $self->package->xsh } <<CONST;
SV*
$name()
	CODE:
		$ctype_to_sv
	OUTPUT:
		RETVAL

CONST
}

1;
