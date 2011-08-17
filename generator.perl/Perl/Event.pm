package Perl::Event;
use Perl::Functions;
use strict;
our @ISA = qw(Event Perl::Function);

sub generate {
	my ($self) = @_;
	
	if ($self->package->is_responder) {
		$self->generate_pm;
		$self->generate_h;
		$self->generate_cpp;
	}
	else {
		$self->generate_xs;
	}
}

sub generate_xs {
	my ($self) = @_;
	
	my $cpp_class_name = $self->cpp_class_name;
	
	my $perl_name = $self->has('overload_name') ?
		$self->overload_name : $self->name;
	
	$self->SUPER::generate_xs(
		cpp_call => "THIS->${cpp_class_name}::" . $self->name,
		perl_name => "${cpp_class_name}::$perl_name",
		extra_items => [
			'// item 0: THIS',	# automatic variable
		],
	);
}

sub generate_h {
	my ($self) = @_;
	my $name = $self->name;
	my $rettype = $self->params->cpp_rettype;
	my $inputs = join(', ', @{ $self->params->as_cpp_funcdef });
	
	print { $self->package->hh } <<EVENT;
		$rettype $name($inputs);
EVENT
}

sub generate_cpp {
	my ($self) = @_;
	
	my @args;		# names as they will be used in the C++ call
	my @defs;		# defs necessary for the XS call
	my @precode;	# any required pre-call code
	my @xspush;		# pushes to XS stack
	# function will supply the call code
	my @postcode;	# any required post-call code
	my $stack_count = 0;
	
	push @xspush, "XPUSHs(newRV_noinc((SV*)perl_link_data->perl_object));";
	$stack_count++;
	
	if ($self->params->has('cpp_input')) {
		for my $param ($self->params->cpp_input) {
			push @args, $param->as_cpp_funcdef;
			
			my $action = $param->action;
			if ($action eq 'input') {
				my $svname = $param->name . '_sv';
				
				my ($defs, $code) = $param->output_converter($svname);
				push @defs,
					qq(SV* $svname;),
					@$defs;
				push @precode,
					qq($svname = sv_newmortal();),
					@$code;
				if ($param->must_not_delete) {
					push @precode, 
						qq(must_not_delete_cpp_object($svname, true););
				}
				push @xspush, "XPUSHs($svname);";
				$stack_count++;
			}
			#
			# currently don't accept output or error
			# as actions for calls from c++ to perl
			#
			#elsif ($action eq 'output') {
			#	push @init, $param->as_cpp_def;
			#	push @outputs, $param;
			#}
			#elsif ($action eq 'error') {
			#	push @init, $param->as_cpp_def;
			#	push @postcode, $param->xs_error_code;
			#}
			
			if ($param->has('length')) {
				my $name = $param->name;
				my $lname = $param->length->name;
			}
			elsif ($param->has('count')) {
				my $name = $param->name;
				my $cname = $param->count->name;
			}
		}
	}
	
	# If we don't have any perl inputs, we won't prepare
	# the stack variables. If we have returns, this is a
	# problem. It won't affect us now, as under the current
	# implementation, all cpp_to_perl calls have at least
	# the perl object as an input. But it may bite us later.
	if ($stack_count) {
		push @precode, '' if @precode;
		push @precode,
			'be_app->LockLooper();	// lock before manipulating stack',
			'dSP;',
			'ENTER;',
			'SAVETMPS;',
			"//EXTEND(SP, $stack_count);",
			'PUSHMARK(SP);',
			'',
			@xspush,
			'',
			'PUTBACK;';		
	}
	
	my @return;
	if ($self->params->has('cpp_output') and $self->params->cpp_output->type_name ne 'void') {
		my $retval = $self->params->cpp_output;
		my $retname = $retval->name . '_sv';
		
		my ($defs, $code) = $retval->input_converter($retname);
		push @defs,
			$retval->as_cpp_def,
			"SV* $retname;",
			@$defs;
		push @postcode,
			"$retname = POPs;",
			@$code,
			'PUTBACK;';
		push @return,
			'',
			qq(return $retval->{name};);
		#
		# currently don't accept output or error
		# as actions for returns from perl to c++
		#
		#my $action = $retval->action;
		#if ($action eq 'output') {
		#	push @init, $retval->as_cpp_def;
		#	push @outputs, $retval;
		#}
		#elsif ($action eq 'error') {
		#	push @init, $retval->as_cpp_def;
		#	push @postcode, $retval->xs_error_code;
		#}
	}
	
	push @postcode,
		'FREETMPS;',
		'LEAVE;',
		'be_app->UnlockLooper();	// unlock after manipulating stack',
		@return;
		
	
	my $name = $self->name;	
	my $rettype = $self->params->cpp_rettype;
	my $cpp_class_name = $self->cpp_class_name;
	my $cpp_parent_name = $self->package->cpp_parent;
	
	my $inputs = join(', ', @args);	
	my $parent_inputs = join(', ', @{ $self->params->as_cpp_parent_call });
	
	if ($rettype ne 'void') {
		push @defs, 'int perl_return_count;';
	}
	
	my $fh = $self->package->cpph;

	print $fh <<EVENT;
$rettype ${cpp_class_name}::$name($inputs) {
	if (perl_link_data->perl_object == NULL) {
		return ${cpp_parent_name}::$name($parent_inputs);
	}
	else {
		DUMPME(1,perl_link_data->perl_object);
EVENT
	
	if (@defs) {
		for my $def (@defs) {
			print $fh "\t\t$def\n";
		}
		print $fh "\t\t\n";
	}
	
	if (@precode) {
		for my $line (@precode) {
			print $fh "\t\t$line\n";
		}
		print $fh "\t\t\n";
	}
	
	if ($rettype eq 'void') {
		print $fh  <<CALL;
		call_method("$name", G_DISCARD);
		SPAGAIN;
CALL
	}
	else {
		print $fh <<CALL;
		perl_return_count = call_method("$name", G_SCALAR);
		SPAGAIN;
		
		// need to add some real error checking here
		if (perl_return_count != 1)
			DEBUGME(4, "Got a bad number of returns from perl call: %d", perl_return_count);
CALL
	}
	
	if (@postcode) {
		print $fh "\t\t\n";
		for my $line (@postcode) {
			print $fh "\t\t$line\n";
		}
	}
	
	print $fh <<EVENT;
	}
} // ${cpp_class_name}::$name

EVENT
}

1;
