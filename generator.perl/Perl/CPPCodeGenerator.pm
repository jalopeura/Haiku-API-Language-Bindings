package Perl::ResponderPackage;
use strict;

sub generate_cpp_preamble {
	my ($self) = @_;
	
	print { $self->{cpph} } <<TOP;
/*
 * Automatically generated file
 */

#include "$self->{filename}.h"

TOP
}

sub generate_cpp_method {
	my ($self, $method, $params) = @_;
	
	my $fh = $self->{cpph};
	
	my $cpp_class_name = $self->{cpp_class};
	my $cpp_parent_name = $self->{cpp_parent};
	my $perl_class_name = $self->{name};
	
	my (@inputs, @parent_inputs);
	for my $p (@{ $params->{cpp_inputs} }) {
		push @inputs, "$p->{type} $p->{name}";
		push @parent_inputs, $p->{name};
	}
	my $inputs = join(', ', @inputs);
	my $parent_inputs = join(', ', @parent_inputs);
	my $name = $method->name;
	
	if ($method->isa('Constructor')) {
		print $fh <<FUNC;
${cpp_class_name}::$cpp_class_name($inputs)
	: $cpp_parent_name($parent_inputs) {}

FUNC
	}
	elsif ($method->isa('Destructor')) {
		print $fh <<FUNC;
${cpp_class_name}::~$cpp_class_name() {
//	DEBUGME(4, "Deleting $cpp_class_name");
	
	// if the perl object was previously unlinked,
	// we no longer need to keep the data around
	if (perl_link_data->perl_object == NULL)
		delete perl_link_data;
}

FUNC
	}
	elsif ($method->isa('Event')) {
		my (@stackdefs, @stackputs, $stack_count, $void_return, $count, $gflags);
		
		my $retval = $params->{cpp_output};
		$retval->{type} ||= 'void';
		if ($retval->{type} ne 'void') {
			push @stackdefs, qq($retval->{type} $retval->{name};);
			push @stackdefs, qq(SV* $retval->{name}_sv;);
			push @stackdefs, qq(int count;);
			$count = 'count = ';
			$gflags = 'G_SCALAR';
		}
		else {
			$void_return = 1;
			$gflags = 'G_VOID';
		}
		
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
		my $stackdefs = join("\n\t\t", @stackdefs) || '// nothing to define';
		my $stackputs = join("\n\t\t", @stackputs) || '// nothing to convert';
		$stack_count++;	# for the perl object itself
		
		print $fh <<FUNC;
$retval->{type} ${cpp_class_name}::$name($inputs) {
	if (perl_link_data->perl_object == NULL) {
		return ${cpp_parent_name}::$name($parent_inputs);
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
		
		${count}call_method("$name", $gflags);
		
FUNC
		
		# here deal with return
		unless ($void_return) {
			my $conversion = $self->{types}->input_converter($retval->{type}, $retval->{name}, "$retval->{name}_sv");
			print $fh <<FUNC;
		SPAGAIN;
		
		// need to add some real error checking here
//		if (count != 1)
//			DEBUGME(4, "Got a bad number of returns from perl call: %d", count);

		$retval->{name}_sv = POPs;
		$conversion
		
		PUTBACK;
FUNC
		}
		
		print $fh <<FUNC;
		FREETMPS;
		LEAVE;
FUNC
		unless ($void_return) {
			print $fh <<FUNC;
		
		return $retval->{name};
FUNC
		}
		
		print $fh <<FUNC;
	}
} // ${cpp_class_name}::$name

FUNC
	}
}

sub generate_cpp_postamble {
	# nothing to do
}

1;
