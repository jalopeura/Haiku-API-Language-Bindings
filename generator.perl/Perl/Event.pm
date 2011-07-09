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

sub generate_xs_function {
	my ($self, $options) = @_;
	my $cpp_class_name = $self->cpp_class_name;
	my $name = "${cpp_class_name}::" . $self->name;
	$options->{name} = "${cpp_class_name}::$options->{name}";
	
	$options->{code} ||= [];
	
	my $call_args = join(', ', @{ $self->params->as_cpp_call });
	if ($options->{rettype} eq 'void') {
		push @{ $options->{code} }, qq(THIS->$name($call_args););
	}
	else {
		my $type = $self->types->type($options->{rettype});
		if ($type->has('target')) {
			push @{ $options->{init} }, "$options->{rettype} OBJ;";
			$options->{rettype} = 'SV*';
			my $class = $type->target;
			push @{ $options->{code} },
				qq(OBJ = THIS->$name($call_args);),
				qq{RETVAL = create_perl_object((void*)OBJ, "$class");};
			
			if ($self->params->cpp_output->must_not_delete) {
				push @{ $options->{code} },
					qq{must_not_delete_cpp_object(RETVAL, true);},
			}
		}
		else {
			push @{ $options->{code}}, qq(RETVAL = THIS->$name($call_args););
		}
	}
		
	$self->SUPER::generate_xs_function($options);
}

sub generate_h {
	my ($self) = @_;
	my $name = $self->name;
	my $rettype = $self->params->cpp_rettype;
	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	
	print { $self->package->hh } <<EVENT;
		$rettype $name($inputs);
EVENT
}

sub generate_cpp {
	my ($self) = @_;
	
	my $name = $self->name;
	my $rettype = $self->params->cpp_rettype;
	my $cpp_class_name = $self->cpp_class_name;
	my $inputs = join(', ', @{ $self->params->as_cpp_input });
	my $cpp_parent_name = $self->package->cpp_parent;
	my $parent_inputs = join(', ', @{ $self->params->as_cpp_parent_input });
	
	my ($stackcount, $stackdefs, $stackputs) = $self->params->as_xs_call;
	$stackcount++;	# for the perl object itself
	
	my $void_return = $rettype eq 'void';
	
	my $fh = $self->package->cpph;

	print $fh <<EVENT;
$rettype ${cpp_class_name}::$name($inputs) {
	if (perl_link_data->perl_object == NULL) {
		return ${cpp_parent_name}::$name($parent_inputs);
	}
	else {
EVENT
	
	my $retval;
	unless ($void_return) {
		$retval = $self->params->cpp_output;
		print $fh "\t\t", $retval->as_cpp_input, ";\n";
		my ($def, $put) = $retval->as_xs_call;
		for my $line (@$def) {
			print $fh "\t\t$line\n";
		}
		print $fh "\t\tint perl_return_count;\n";
	}
	
	for my $line (@$stackdefs) {
		print $fh "\t\t$line\n";
	}
	
	print $fh <<EVENT;
		
		dSP;
		
		ENTER;
		SAVETMPS;
		
		EXTEND(SP, $stackcount);
		PUSHMARK(SP);
		
		PUSHs(perl_link_data->perl_object);
		
EVENT
	
	for my $line (@$stackputs) {
		print $fh "\t\t$line\n";
	}
	
	print $fh "\t\tPUTBACK;\n\t\t\n";
	
	if ($void_return) {
		print $fh qq(\t\tcall_method("$name", G_VOID);\n\t\t\n);
	}
	else {
		my $type = $self->types->type($retval->type);
		my $retname = $retval->name . '_sv';
		my $converter = $type->input_converter($retval->name, $retname);
		print $fh <<EVENT;
		perl_return_count = call_method("$name", G_SCALAR);
		
		// need to add some real error checking here
//		if (count != 1)
//			DEBUGME(4, "Got a bad number of returns from perl call: %d", count);
		
		SPAGAIN;
		$retname = POPs;
		$converter
		PUTBACK;
		
EVENT
	}
	
	print $fh <<EVENT;
		FREETMPS;
		LEAVE;
EVENT
	
	
	unless ($void_return) {
		print $fh "\t\t\n\t\treturn ", $retval->name ,";\n";
	}
		
	print $fh <<EVENT;
	}
} // ${cpp_class_name}::$name

EVENT
}

1;
