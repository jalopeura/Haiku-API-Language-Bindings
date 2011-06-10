package Perl::Generator;
use strict;

sub generate_cpp_method {
	my ($self, $fh, %options) = @_;
	
	my $function = $options{function};
	my $params = $options{params};
	my $cpp_class_name = $options{cpp_class_name};
	my $cpp_parent_name = $options{cpp_parent_name};
	my $perl_class_name = $options{perl_class_name};
	
	my (@inputs, @parent_inputs);
	for my $p (@{ $params->{cpp_inputs} }) {
		push @inputs, "$p->{type} $p->{name}";
		push @parent_inputs, $p->{name};
	}
	my $inputs = join(', ', @inputs);
	my $parent_inputs = join(', ', @parent_inputs);
	my $rettype = $params->{cpp_output}{type};
	my $name = $function->name;
	
	if ($function->isa('Constructor')) {
		print $fh <<FUNC;
${cpp_class_name}::$cpp_class_name($inputs)
	: $cpp_parent_name($parent_inputs) {}

FUNC
	}
	elsif ($function->isa('Destructor')) {
		print $fh <<FUNC;
${cpp_class_name}::~$cpp_class_name() {
	DEBUGME(4, "Deleting $cpp_class_name");
	
	// if the perl object was previously unlinked,
	// we no longer need to keep the data around
	if (perl_link_data->perl_object == NULL)
		delete perl_link_data;
}

FUNC

#	// if perl_obj is null, we've been unlinked
#	if (perl_obj != NULL) {
#		// if we point to nothing, perl_obj has already been garbage-collected
#		if (SvRV(perl_link_data->perl_object) != NULL) {
#			// we're being deleted so don't let perl delete us again
#			must_not_delete_cpp_object(perl_link_data->perl_object, true);
#			// decrement the reference count
#//DEBUGME(4, "Decrementing reference count");
#//			SvREFCNT_dec(perl_link_data->perl_object);
#			sv_2mortal(perl_link_data->perl_object);
#		}
#	}

	}
	elsif ($function->isa('Event')) {
		my (@stackdefs, @stackputs, $stack_count);
		for my $p (@{ $params->{xs_inputs} }) {
			my $conversion = $self->{types}->output_converter($p->{type}, $p->{name}, "$p->{name}_sv");
			
#			# objects
#			if ($p->{passback} and $p->{passback}  ne 'builtin') {
#				# converter assumes must_not_delete = true for objects passed back
#				# if this turns out not to be the case, we must fix it here
#				$conversion=~s/\bCLASS\b/"$p->{passback}"/;
#			}
#			elsif (not $p->{passback}) {
#				die "No passback value provided";
#			}
			
			$stack_count++;
			push @stackdefs, qq(SV* $p->{name}_sv;);
			push @stackputs, qq($p->{name}_sv = sv_newmortal(););
			if ($p->{count}) {
				push @stackdefs, qq(int count_$p->{name} = $p->{count}{name};);
			}
			push @stackputs, $conversion;
			if ($p->{must_not_delete}) {
				push @stackputs, qq(must_not_delete_cpp_object($p->{name}_sv, true););
			}
			push @stackputs, qq(PUSHs($p->{name}_sv););
		}
		my $stackdefs = join("\n\t\t", @stackdefs);
		my $stackputs = join("\n\t\t", @stackputs);
		$stack_count++;	# for the perl object itself
		
		print $fh <<FUNC;
$rettype ${cpp_class_name}::$name($inputs) {
	if (perl_link_data->perl_object == NULL) {
		${cpp_parent_name}::$name($parent_inputs);
	}
	else {
		$stackdefs
	
		dSP;
		
		ENTER;
		SAVETMPS;
			
		EXTEND(SP, $stack_count);
		PUSHMARK(SP);
		
		PUSHs(perl_link_data->perl_object);
		
		$stackputs
		
		PUTBACK;
		
		call_method("$name", G_DISCARD);
		
		FREETMPS;
		LEAVE;
	}
} // ${cpp_class_name}::$name

FUNC
	}	
}

1;
