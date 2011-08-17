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

sub generate_exports {
	my ($self) = @_;
	
	if ($self->has('plains')) {
		my @exports;
		
		for my $p ($self->plains) {
			push @exports, $p->has('overload_name') ?
				$p->overload_name : $p->name;
		}
	
		print { $self->package->pmh } "\n",
			'my @exported_functions = qw(',
			join(' ', @exports),
			");\n";
	}
}

sub exports {
	my ($self) = @_;
	if ($self->has('plains')) {
		return ['@exported_functions'];
	}
	else {
		return [];
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
		if ($self->isa('Perl::Constructor')) {
			$name .= $self->overload_name;
		}
		else {
			$name = $self->overload_name;
		}
	}
	my $perl_class_name = $self->perl_class_name;
	
	print { $self->package->pmh } <<POD;
#
# POD for ${perl_class_name}::$name
#

POD
}

# expects the overload function to have set some options
sub generate_xs {
	my ($self, %options) = @_;
	
	my $cpp_call = $options{cpp_call} || $self->name;
	
	my $perl_name = $options{perl_name};
	
	my @xsargs;		# names as they will be passed to the XS call
	my @cppargs;	# names as they will be passed to the C++ call
	my @preinit;	# defs that need to exist before Perl converts the arguments
	my @input;		# defs for the C++ versions of the Perl arguments
	my @init;		# additional defs necessary for the C++ call
	my @precode;	# any required pre-call code
	my @code;		# the code itself
	my @postcode;	# any required post-call code
	my @outputs;		# what we will output
	my $has_errors;
	
	if ($options{add_CLASS}) {
		push @xsargs, 'CLASS';
		push @input, 'char* CLASS;';
	}
	
	if ($options{force_return}) {
		push @outputs, $options{force_return};
	}
	
	# set up any extra items
	my $i = -1;
	if ($options{extra_items}) {
		for my $line (@{ $options{extra_items} }) {
			$i++;
			push @precode, $line;
		}
	}
	
	# here parse the params
	my $has_defaults;
	if ($self->params->has('cpp_input')) {
		for my $param ($self->params->cpp_input) {
			$i++;
			
			my $action = $param->action;
			if ($action eq 'input') {
				if ($param->has('default')) {
					push @precode, "// item $i: $param->{name}";
					push @init, $param->as_cpp_def;
					unless ($has_defaults) {
						push @xsargs, '...';
						$has_defaults = 1;
					}
					my ($defs, $code, $postcode) = $param->input_converter("ST($i)");
					push @init, @$defs;
					push @precode,
						qq(if (items > $i) {),
						map( {"\t$_" } @$code ),
						qq(});
					push @postcode, @$postcode;
				}
				elsif ($param->is_array_or_string) {
					push @input, "SV* $param->{name}_sv;";
					push @xsargs, $param->name . '_sv';
					my $options = {
						suffix => '_sv'	# use a suffix on the variable name
					};
					my ($defs, $code, $postcode) = $param->input_converter($param->name, $options);
					push @init,
						$param->as_cpp_def,
						@$defs;
					push @precode,
						 "// item $i: $param->{name}",
						 @$code;
					push @postcode, @$postcode;
				}
				else {
					push @precode, "// item $i: $param->{name}";
					push @input, $param->as_cpp_def;
					push @xsargs, $param->name;
				}
				if ($param->type->has('target') and $param->must_not_delete) {
					push @precode,
						qq{must_not_delete_cpp_object(ST($i), true);};
				}
			}
			elsif ($action eq 'output') {
				push @init, $param->as_cpp_def;
				push @outputs, $param;
			}
			elsif ($action=~/(length|count)\[/) {
				$i--;
				push @precode, "// not an XS input: $param->{name}";
				push @init, $param->as_cpp_def;
			}
			elsif ($action eq 'error') {
				$has_errors = 1;
				push @init, $param->as_cpp_def;
				push @postcode, $param->xs_error_code;
			}
		}
	}
	
	if ($self->params->has('cpp_output') and $self->params->cpp_output->type_name ne 'void') {
		my $retval = $self->params->cpp_output;
		my $action = $retval->action;
		if ($action eq 'output') {
			unshift @outputs, $retval;
			push @init, $retval->as_cpp_def;
		}
		elsif ($action eq 'error') {
			$has_errors = 1;
			my $errname = $retval->name . '_sv';
			push @init, $retval->as_cpp_def;
			push @postcode, $retval->xs_error_code;
		}
	}
	if ($has_errors) {
		push @init, "SV* error_sv;";
	}
	
	# do the C++ call
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	
	if ($self->params->has('cpp_output') and $self->params->cpp_output->type_name ne 'void') {
		my $retname = $self->params->cpp_output->name;
		my $type_name = $self->params->cpp_output->type_name;
		my $cast;
		push @code, qq($retname = $cast$cpp_call($call_args););
	}
	else {
		push @code, qq($cpp_call($call_args););		
	}
	
	my $rettype = 'void';	# default
	my $retcount = scalar @outputs;
	
	# handle perl outputs
	if ($retcount) {
		for my $output (@outputs) {
			my $type = $output->type;
			if ($output->is_array_or_string) {
				my $options = {
					suffix => '_sv'	# use a suffix on the variable name
				};
				
				my ($defs, $code, $precode) = $output->output_converter($output->name, $options);
				push @init,
					@$defs;
				push @postcode,
					 @$code;
				push @precode,
					 @$precode;
			}
			elsif ($type->has('target')) {
				my $retname = $output->name;
				my $svname = $retname . '_sv';
				my $class;
				if ($self->isa('Perl::Constructor')) {
					$class = 'CLASS';
				}
				else {
					$class = qq("$type->{target}");
				}
				
				my $mnd = $output->must_not_delete ? 'true' : 'false';
				my $type_name = $output->type->name;
				
				if ($type_name=~/\*$/) {
					push @postcode,
						qq{$svname = create_perl_object((void*)$retname, $class, $mnd);};
						if ($options{custom_constructor}) {
							push @postcode,
								qq($retname->perl_link_data = get_link_data($svname););
						}
				}
				else {
					push @postcode,
						qq{$svname = create_perl_object((void*)&$retname, $class, $mnd);};
				}
				
				# for debugging
				push @postcode, qq(DUMPME(1,$svname););
			}
		}
		
		if ($retcount > 1) {
			push @postcode, "EXTEND(SP, $retcount);";
			
			for my $i (0..$#outputs) {
				my $param = $outputs[$i];
				my $svname = $param->name . '_sv';
				push @init, "SV* $svname = newSV(0);	// retcount > 1";
				my $type = $param->type;
				
				# if we're a target, we've already converted it
				unless ($type->has('target') or $outputs[$i]->is_array_or_string) {
					my ($defs, $code, $precode) = $param->output_converter("$svname");
					push @init, @$defs;
					push @code, @$code;
					push @precode, @$precode;
				}
				push @postcode, qq(PUSHs(sv_2mortal($svname)););
			}
		}
		else {
			my $retname = $outputs[0]->name;
			$rettype = $outputs[0]->type->name;
			if ($outputs[0]->type->has('target') or
				$outputs[0]->is_array_or_string) {
				# we already converted the object, so we change the rettype
				$rettype = 'SV*';
				$retname .= '_sv';
				push @init, "SV* $retname = newSV(0);	// retcount == 1";
			}
			if ($outputs[0]->type->has('target')) {
				push @postcode,
					"RETVAL = newSVsv($retname);",
					"SvREFCNT_dec($retname);",
			}
			else {
				if ($outputs[0]->type->builtin eq 'char') {
					my $length = $outputs[0]->has('repeat') ? $outputs[0]->repeat : 1;
					push @init, qq(int LENGTH = $length; // length for return value);
				}
				push @postcode, "RETVAL = $retname;";
			}
		}
	}
	# return true if no errors and no other return value
	elsif ($has_errors) {
		$rettype = 'bool';
		$retcount ||= 1;
		push @code, 'RETVAL = true;';
	}
	
	# now we can finally write the thing
	
	my $fh = $self->package->xsh;
	
	if ($options{comment}) {
		print $fh $options{comment};
	}
	
	my $input = join(', ', @xsargs);
	
	print $fh <<DEF;
$rettype
$perl_name($input)
DEF
	
	if (@preinit) {
		print $fh "\tPREINIT:\n";
		print $fh map { "\t\t$_\n" } @preinit;
	}
	
	if (@input) {
		print $fh "\tINPUT:\n";
		print $fh map { "\t\t$_\n" } @input;
	}
	
	if (@init) {
		print $fh "\tINIT:\n";
		print $fh map { "\t\t$_\n" } @init;
	}
	
	my @allcode;
	if (@precode) {
		push @allcode, @precode;
	}
	if (@code) {
		push @allcode, '' if @allcode;
		push @allcode, @code;
	}
	if (@postcode) {
		push @allcode, '' if @allcode;
		push @allcode, @postcode;
	}
	if (@allcode) {
		if ($retcount > 1) {
			print $fh "\tPPCODE:\n";
		}
		else {
			print $fh "\tCODE:\n";
		}
		print $fh map { "\t\t$_\n" } @allcode;
	}
	
	if ($retcount == 1) {
		print $fh <<OUT;
	OUTPUT:
		RETVAL
OUT
	}
	
	print $fh "\n";
}

sub generate_xs_function {
	my ($self, $options) = @_;
	
	my $fh = $self->package->xsh;
	
	if ($options->{comment}) {
		print $fh $options->{comment};
	}
	
	my $rettype = $options->{retcount} == 1 ? $options->{rettype} : 'void';
	
	my $input = join(', ', @{ $options->{args} });
	
	print $fh <<DEF;
$rettype
$options->{name}($input)
DEF
	
	if ($options->{preinit} and @{ $options->{preinit} }) {
		print $fh "\tPREINIT:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{preinit} };
	}
	
	if ($options->{input} and @{ $options->{input} }) {
		print $fh "\tINPUT:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{input} };
	}
	
	if ($options->{init} and @{ $options->{init} }) {
		print $fh "\tINIT:\n";
		print $fh map { "\t\t$_\n" } @{ $options->{init} };
	}
	
	my @code;
	if ($options->{precode} and @{ $options->{precode} }) {
		push @code, @{ $options->{precode} };
	}
	if ($options->{code} and @{ $options->{code} }) {
		push @code, '' if @code;
		push @code, @{ $options->{code} };
	}
	if ($options->{postcode} and @{ $options->{postcode} }) {
		push @code, '' if @code;
		push @code, @{ $options->{postcode} };
	}
	if (@code) {
		if ($options->{retcount} > 1) {
			print $fh "\tPPCODE:\n";
		}
		else {
			print $fh "\tCODE:\n";
		}
		print $fh map { "\t\t$_\n" } @code;
	}
	
	if ($options->{retcount} == 1) {
		print $fh <<OUT;
	OUTPUT:
		RETVAL
OUT
	}
	
	print $fh "\n";
}

1;
