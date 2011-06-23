package Perl::Package;
use strict;

sub generate_xs_preamble {
	my ($self) = @_;
	
	my $perl_class_name = $self->{name};
	my $perl_module_name = $self->{module}{name};
	
	print { $self->{xsh} } <<TOP;
#
# Automatically generated file
#

MODULE = $perl_module_name	PACKAGE = $perl_class_name

TOP
}

=pod

generate_xs_function

we should make it generate a single XS sub for all overloaded C++ subs

this will require a lot more work; for now let's use the simpler way

each overloaded function gets passed through once

=cut

sub generate_xs_function {
	my ($self, $function, $params) = @_;
	
	my $fh = $self->{xsh};
	
	my $cpp_class_name = $self->{cpp_class};
	my $perl_class_name = $self->{name};
	
	my @xs_inputs;	# what gets passed in to the XS sub
	my @xs_input_defs;	# define the inputs here
	my @xs_opt_defs;	# convert the optional inputs here
	my @xs_init;	# additional defines
	my @xs_pre_init;	# additional defines for before conversions from Perl
	my @must_not_delete;	# objects that must not be deleted
	
	my ($req_count, $opt_count);
	for my $p (@{ $params->{xs_inputs} }) {
		my $type = $p->{type};
		if ($p->{deref}) {
			$type=~s/\*$//;
		}
		if ($p->{default}) {
			$opt_count++;
			push @xs_init, "$type $p->{name} = $p->{default};";
			push @xs_opt_defs, $self->{types}->input_converter($type, $p->{name}, 'ST(%d)');
		}
		else {
			$req_count++;
			push @xs_inputs, $p->{name};
			push @xs_input_defs, "$type $p->{name};";
		}
		if ($p->{count}) {
			push @xs_init, "$p->{count}{type} $p->{count}{name} = count_$p->{name};";
			push @xs_pre_init, "int count_$p->{name};";
		}
	}
	if ($opt_count) {
		push @xs_inputs, '...';
	}
	for my $p (@{ $params->{xs_outputs} }, @{ $params->{xs_errors} }) {
		my $type = $p->{type};
		if ($p->{deref}) {
			$type=~s/\*$//;
		}
		push @xs_init, "$type $p->{name};";
		push @xs_init, "SV* $p->{name}_sv;";
		
		if ($p->{'must-not-delete'} eq 'true') {
			push @must_not_delete, qq(must_not_delete_cpp_object($p->{name}_sv, true););
		}
	}
	
	my @cpp_inputs;
	for my $p (@{ $params->{cpp_inputs} }) {
		my $name = $p->{name};
		if ($p->{deref}) {
			$name = "&$name";
		}
		push @cpp_inputs, $name;
	}
	my $cpp_inputs = join(', ', @cpp_inputs);
	
	my ($xs_name, $xs_rettype, @cpp_call, $comment);
	
	if ($function->isa('Constructor')) {
		if ($function->overload_name) {
			$xs_name = 'new' . $function->overload_name;
			$req_count++;
			unshift @xs_inputs, 'CLASS';
			unshift @xs_input_defs, 'char* CLASS;';
			$comment = <<CMT;
# Note that this method is not prefixed by the class name.
#
# This is because for prefixed methods, xsubpp will turn the first perl
# argument into the CLASS variable (a char*) if the method name is 'new',
# and into the THIS variable (the object pointer) otherwise. So we need to
# trick xsubbpp by leaving off the prefix and defining CLASS ourselves
CMT
		}
		else {
			$xs_name = "${cpp_class_name}::new";
		}
		$xs_rettype = "SV*";
		push @xs_init, qq($cpp_class_name* THIS;);
#push @xs_init, qq(DEBUGME(4, "About to create %s", CLASS););
		push @cpp_call,
			qq(THIS = new $cpp_class_name($cpp_inputs);),
			qq(RETVAL = newSV(0);),
			qq(sv_setsv(RETVAL, create_perl_object((void*)THIS, CLASS)););
#push @cpp_call, qq(DEBUGME(4, "Creating perl object: %d", RETVAL););
		
		if ($self->isa('Perl::ResponderPackage')) {
			push @cpp_call,
				qq(THIS->perl_link_data = get_link_data(RETVAL););
		}
		
		if ($self->{binding}{must_not_delete} eq 'true') {
			push @cpp_call, qq(must_not_delete_cpp_object(RETVAL, true););
		}
	}
	elsif ($function->isa('Destructor')) {
		$xs_name = "DESTROY";
		@xs_inputs = ('perl_obj');
		@xs_input_defs = ('SV* perl_obj;');
		@xs_init = (
			"$cpp_class_name* cpp_obj;",
			"object_link_data* link;",
		);
		$comment = <<CMT;
# Note that this method is not prefixed by the class name.
#
# This is because if we prefix the class name the first argument is
# automatically converted into the THIS pointer, and we no longer have
# access to the Perl object. But we need that access in order to determine
# whether we're allowed to delete the C++ object, and to clean up the Perl
# object.
CMT
		$xs_rettype = "void";
		push @cpp_call,
#qq(DEBUGME(4, "Deleting $perl_class_name");),
			qq(link = get_link_data(perl_obj);),
			qq(if (! PL_dirty && link->can_delete_cpp_object) {),
			qq(	cpp_obj = (${cpp_class_name}*)link->cpp_object;),
#qq(DEBUGME(4, "Deleting corresponding c++ object ($cpp_class_name)");),
			qq(	delete cpp_obj;),
			qq(	link->cpp_object = NULL;),
			qq(}),
			qq(unlink_perl_object(perl_obj););
#push @cpp_call, qq(DEBUGME(4, "Leaving after destroying $perl_class_name");),
	}
	else {
		my $func_call;
		$xs_rettype = $params->{cpp_output}{type} || 'void';
		if ($function->isa('Method')) {
			$xs_name = "${cpp_class_name}::" . $function->name;
			$func_call = "THIS->" . $function->name;
		}
		elsif ($function->isa('Event')) {
			$xs_name = "${cpp_class_name}::" . $function->name;
			$func_call = "THIS->${cpp_class_name}::" . $function->name;
		}
		elsif ($function->isa('Static')) {
			$xs_name = $function->name;
			$func_call = "${cpp_class_name}::" . $function->name;
		}
		elsif ($function->isa('Plain')) {
			$xs_name = $func_call = $function->name;
		}
		
		if ($xs_rettype eq 'void') {
			push @cpp_call, "$func_call($cpp_inputs);"
		}
		else {
			my ($builtin, $target) = $self->{types}->get_builtin($xs_rettype);
			if ($target) {
				my $target_class = $xs_rettype;
				$xs_rettype = "SV*";
				push @xs_init, qq($target_class OBJ;);
				push @cpp_call,
					"OBJ = $func_call($cpp_inputs);",
					$self->{types}->output_converter($target_class, 'OBJ', 'RETVAL');
				
				if ($params->{cpp_output}{must_not_delete} eq 'true') {
					push @cpp_call, qq(must_not_delete_cpp_object(RETVAL, true););
				}
			}
			else {
				push @cpp_call, "RETVAL = $func_call($cpp_inputs);"
			}
		}
	}
	
	if ($comment) {
		print $fh $comment;
	}
	
	# xsub definition
	my $xs_inputs = join(', ', @xs_inputs);
	print $fh <<FUNCDEF;
$xs_rettype
$xs_name($xs_inputs)
FUNCDEF
	
	# PREINIT section
	my $xs_pre_init = join("\n\t\t", @xs_pre_init);
	if ($xs_pre_init) {
		print $fh <<DEFS;
	PREINIT:
		$xs_pre_init
DEFS
	}
	
	my $xs_input_defs = join("\n\t\t", @xs_input_defs);
	if ($xs_input_defs) {
		print $fh <<DEFS;
	INPUT:
		$xs_input_defs
DEFS
	}
	
	# INIT section
	my $xs_init = join("\n\t\t", @xs_init);
	if ($xs_init) {
		print $fh <<DEFS;
	INIT:
		$xs_init
DEFS
	}
	
	# CODE section
	print $fh "\tCODE:\n";
	
	if ($opt_count) {
		my $i = $req_count+1;
		my $last = $i + $opt_count;
		while ($i < $last) {
			$i++;
			my $code = sprintf(shift(@xs_opt_defs), $i-1);	# -1 because stack index is 0-based
			print $fh <<OPT;
		if (items >= $i)
			$code
OPT
		}
	}
	
	my $cpp_call = join("\n\t\t", @cpp_call);
	print $fh qq(\t\t$cpp_call\n);
	
	# error processing
	if (@{ $params->{xs_errors} }) {
		my $errvar = "$self->{module}{name}::Error";
		for my $error (@{ $params->{xs_errors} }) {
			print $fh <<ERR;
		if ($error->{name} != $error->{success}) {
			// this doesn't seem to be working...
            error_sv = get_sv("!", 1);
			sv_setiv(error_sv, (IV)error);
			// ...so use this for now
            error_sv = get_sv("$errvar", 1);
			sv_setiv(error_sv, (IV)error);
			XSRETURN_UNDEF;
		}
ERR
		}
	}
	
	# objects that must not be deleted (default is that they can be)
	for my $mnd (@must_not_delete) {
		print $fh "\t\t", $mnd, "\n";
	}
	
	if ($xs_rettype ne 'void') {
	print $fh <<OUT;
	OUTPUT:
		RETVAL
OUT
	}
	
	print $fh "\n";
}

sub generate_xs_property {
	my ($self, $property) = @_;
	
	my $fh = $self->{xsh};
	
	my $cpp_class_name = $self->{cpp_class};
	my $perl_class_name = $self->{name};
	my $perl_module_name = $self->{module}{name};
	
	my $name = $property->{name};
	my $type = $property->{type};
	my $svgetter = $self->{types}->input_converter($type, "cpp_obj->$name", 'value');
	my $svsetter = $self->{types}->output_converter($type, "cpp_obj->$name", 'RETVAL');
	
	print $fh <<PROP;
MODULE = $perl_module_name	PACKAGE = ${perl_class_name}::$name

SV*
FETCH(tie_obj)
		SV* tie_obj;
	INIT:
		SV* cpp_obj_sv;
		$cpp_class_name* cpp_obj;
	CODE:
		RETVAL = newSV(0);
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($cpp_class_name*)SvIV(cpp_obj_sv);
		$svsetter;
	OUTPUT:
		RETVAL

void
STORE(tie_obj, value)
		SV* tie_obj;
		SV* value;
	INIT:
		SV* cpp_obj_sv;
		$cpp_class_name* cpp_obj;
	CODE:
		cpp_obj_sv = SvRV(tie_obj);
		cpp_obj = ($cpp_class_name*)SvIV(cpp_obj_sv);
		$svgetter

MODULE = $perl_module_name	PACKAGE = $perl_class_name

SV*
${cpp_class_name}::$name()
	INIT:
		SV* cpp_obj_sv;
		SV* tie_obj;
		HV* tie_obj_stash;
	CODE:
		RETVAL = newSV(0);
		// make our object into an SV* and make a reference to it
		cpp_obj_sv = newSViv((IV)THIS);	// do I need to make this mortal?
		tie_obj = newRV_noinc(cpp_obj_sv);
		
		// bless the reference into the proper class
		tie_obj_stash = gv_stashpv("${perl_class_name}::$name", TRUE);
		sv_bless(tie_obj, tie_obj_stash);
		
		// tie the blessed object to the RETVAL scalar
		sv_magic(RETVAL, tie_obj, PERL_MAGIC_tiedscalar, NULL, 0);
	OUTPUT:
		RETVAL

BOOT:
	CvFLAGS(get_cv("${perl_class_name}::$name", TRUE)) |= CVf_LVALUE;

PROP
}

sub generate_xs_constant {
	my ($self, $constant) = @_;
	
	my $fh = $self->{xsh};
	
	my $cpp_class_name = $self->{cpp_class};
	my $perl_class_name = $self->{name};
	my $perl_module_name = $self->{module}{name};
	
	my $name = $constant->{name};
	
	print $fh <<CONST;
SV*
$name()
	CODE:
		RETVAL = newSViv($name);
	OUTPUT:
		RETVAL

CONST
}

sub generate_xs_postamble {
	# nothing to do
}

1;
