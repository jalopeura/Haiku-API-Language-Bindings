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

sub exports {
	my ($self) = @_;
	if ($self->has('plains')) {
		return ['\@exported_functions'];
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
		$name .= $self->overload_name;
	}
	my $perl_class_name = $self->perl_class_name;
	
	print { $self->package->pmh } <<POD;
#
# POD for ${perl_class_name}::$name
#

POD
}

sub Xgenerate_xs {
	my ($self) = @_;
	
	my $ignore_error_return = $self->isa('Perl::Constructor');
	my $options = $self->params->perl_to_cpp($ignore_error_return);
	
	$options->{name} = $self->name;
	if ($self->has('overload_name')) {
		$options->{name} .= $self->overload_name;
	}
	
	$self->generate_xs_function($options);
}

# expects the overload function to have set some options
sub generate_xs {
	my ($self, %options) = @_;
	
	my $cpp_call = $options{cpp_call} || $self->name;
	
	my $perl_name = $options{perl_name} || $self->name;
	if ($self->has('overload_name')) {
		$perl_name .= $self->overload_name;
	}
	
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
					push @precode,
					qq(if (items > $i) {),
					"\t" . $param->input_converter("ST($i)"),
					qq(});
				}
				else {
					push @precode, "// item $i: $param->{name}";
					push @input, $param->as_cpp_def;
					push @xsargs, $param->name;
				}
			}
			elsif ($action eq 'output') {
				push @init, $param->as_cpp_def;
				push @outputs, $param;
			}
			elsif ($action eq 'error') {
				$has_errors = 1;
				push @init, $param->as_cpp_def;
				push @postcode, $param->xs_error_code;
			}
			
			if ($param->has('length')) {
				my $name = $param->name;
				my $ltype = $param->length->type->name;
				my $lname = $param->length->name;
				push @preinit, "int length_$name;";
				push @init, "$ltype $lname = ($ltype)length_$name;";
			}
			elsif ($param->has('count')) {
				my $name = $param->name;
				my $ctype = $param->count->type->name;
				my $cname = $param->count->name;
				push @preinit, "int count_$name;";
				push @init, "$ctype $cname = ($ctype)count_$name;";
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
		push @code, qq($retname = $cpp_call($call_args););
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
			if ($type->has('target')) {
				my $retname = $output->name;
				my $svname = $retname . '_sv';
				push @init, "SV* $svname = newSV(0);";
				my $class;
				if ($self->isa('Perl::Constructor')) {
					$class = 'CLASS';
				}
				else {
					$class = qq("$type->{target}");
				}
				
				my $mnd = $output->must_not_delete ? 'true' : 'false';
				my $type_name = $output->type->name;
				#if ($output->needs_deref) {
				#	$type_name=~s/\*$//;
				#}
				
				if ($type_name=~/\*$/) {
					push @postcode,
						qq{$svname = newSVsv(create_perl_object((void*)$retname, $class, $mnd));};
						if ($options{custom_constructor}) {
							push @postcode,
								qq($retname->perl_link_data = get_link_data($svname););
						}
				}
				else {
					push @postcode,
						qq{$svname = newSVsv(create_perl_object((void*)&$retname, $class, $mnd));};
				}
				
			}
		}
		
		if ($retcount > 1) {
			push @postcode, "EXTEND(SP, $retcount);";
			
			for my $i (0..$#outputs) {
				my $param = $outputs[$i];
				my $svname = $param->name . '_sv';
				push @init, "SV* $svname = newSV(0);";
				my $type = $param->type;
				
				# if we're a target, we've already converted it
				unless ($type->has('target')) {
					push @postcode, $param->output_converter("$svname"),
				}
				push @postcode, qq(PUSHs(sv_2mortal($svname)););
			}
		}
		else {
			my $retname = $outputs[0]->name;
			$rettype = $outputs[0]->type->name;
			if ($outputs[0]->type->has('target')) {
				# we already converted the object, so we change the rettype
				$rettype = 'SV*';
				$retname .= '_sv';
			}
			if ($outputs[0]->type->has('target')) {
				push @postcode,
					"RETVAL = newSVsv($retname);",
					"// it's already mortal, but RETVAL will mortalize it again",
					"SvREFCNT_inc($retname);";
			}
			else {
				push @postcode, "RETVAL = $retname;";
			}
		}
	}
	# return true if no errors and no other return value
	elsif ($has_errors) {
		$rettype = 'bool';
		$retcount ||= 1;
		push @postcode, 'RETVAL = true;';
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

=pod

	
	# here handle the perl returns
	if ($options->{retcount}) {
		my $type = $self->types->type($outtype);
		my $retname = $output->name;
		
		if ($options->{retcount} > 1) {
			$options->{rettype} = 'void';
		}
	}
	else {	# no returns
		if ($options->{error_return}) {
			my $ret = $self->params->cpp_output->name;
			push @{ $options->{code} }, qq($ret = THIS->$name($call_args););
		}
		else {
#push @{ $options->{code} }, qq(DEBUGME(4, "About to call cpp method ${cpp_class_name}::$name"););
			push @{ $options->{code} }, qq(THIS->$name($call_args););
#push @{ $options->{code} }, qq(DEBUGME(4,"Back from cpp call"););
		}
	}
	
	if ($retcount > 1) {
		if ($self->has('cpp_output') and $self->cpp_output->type ne 'void') {
			$rettype = $self->cpp_output->type;
			if ($self->cpp_output->needs_deref) {
				$rettype=~s/\*$//;
			}
		}
		push @postcode, "EXTEND(SP, $retcount);";
		
		for my $i (0..$#outputs) {
			my $param = $outputs[$i];
			my $svname = $param->name . '_sv';
			push @init, "SV* $svname = newSV(0);";
			my $ptype = $param->type;
			if ($param->needs_deref) {
				$ptype=~s/\*$//;
			}
			my $type = $self->types->type($ptype);
			
			# if we're a target, we've already converted it
			unless ($type->has('target')) {
				push @postcode, $param->output_converter("$svname"),
			}
			else {
				push @postcode, qq(PUSHs(sv_2mortal($svname)););
			}
		}
	}
	elsif ($retcount == 1) {
		$rettype = $outputs[0]->type;
		if ($outputs[0]->needs_deref) {
			$rettype=~s/\*$//;
		}
		push @postcode, "RETVAL = $outputs[0]->{name};";
	}
	# return true if no errors and no other return value
	elsif ($has_errors and not $ignore_error_return) {
		$rettype = 'bool';
		$retcount ||= 1;
		push @postcode, 'RETVAL = true;';
	}
	
	# start XS def and convert XS inputs as necessary

=cut

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

=pod

sub generate_xs_body_code {
	my ($self, $options) = @_;
	
	my $name = $options->{cpp_call_name};
	
	$options->{code} ||= [];
	
	# here handle the C++ call
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	if ($self->params->has('cpp_output')) {
		my $retname = $self->params->cpp_output->name;
		push @{ $options->{code} },
			qq($retname = $name($call_args););
	}
	else {
		push @{ $options->{code} },
			qq($name($call_args););
	}
	
	# here handle the perl returns
	if ($options->{retcount}) {
		my $type = $self->typeobj;
		my $retname = $output->name;
		if ($type->has('target')) {
			my $svname = $retname . '_sv';
			push @{ $options->{init} }, "SV* $svname;";
			my $class = $type->target;
		
		for my $output (@{ $options->{outputs} }) {
			my $outtype = $output->type;
			if ($output->needs_deref) {
				$outtype=~s/\*$//;
			}
		
				my $mnd = $self->package->must_not_delete ? 'true' : 'false';
				
				if ($options->{rettype}=~/\*$/) {
					push @{ $options->{code} },
						qq{$svname = create_perl_object((void*)$retname, "$class", $mnd);};
				}
				else {
					push @{ $options->{code} },
						qq{$svname = create_perl_object((void*)&$retname, "$class", $mnd);};
				}
				
				# if this is the only thing we're returning
				if ($options->{retcount} == 1) {
					# we're creating the object ourself, so we change the rettype
					$options->{rettype} = 'SV*';
					pop @{ $options->{postcode} };
					push @{ $options->{postcode} }, "RETVAL = $svname;";
				}
			}
			else {
				push @{ $options->{code}}, qq($retname = THIS->$name($call_args););
			}
		}
		
		if ($options->{retcount} > 1) {
			$options->{rettype} = 'void';
		}
	}
	else {	# no returns
		if ($options->{error_return}) {
			my $ret = $self->params->cpp_output->name;
			push @{ $options->{code} }, qq($ret = THIS->$name($call_args););
		}
		else {
#push @{ $options->{code} }, qq(DEBUGME(4, "About to call cpp method ${cpp_class_name}::$name"););
			push @{ $options->{code} }, qq(THIS->$name($call_args););
#push @{ $options->{code} }, qq(DEBUGME(4,"Back from cpp call"););
		}
	}
}

=cut

1;
