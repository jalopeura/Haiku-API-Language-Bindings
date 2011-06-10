package Perl::Generator;
require Perl::ParamParser;
require Perl::XSMethodGenerator;
require Perl::HMethodGenerator;
require Perl::CPPMethodGenerator;
require Perl::XSPropertyGenerator;
require Perl::XSConstantGenerator;
require Perl::UtilityCodeGenerator;
use strict;

sub generate_class {
	my ($self, $bindings, $binding, $folder, $xs_prefix, $pm_prefix) = @_;
	my @ret;
#print "Generating class from $binding to $folder\n";

	my $cpp_class_name = $binding->source;
	my $perl_class_name = $binding->target;
	my $perl_module = $bindings->name;
	my $version = $bindings->version;
	
	my ($cpp_responder_name, $cpp_parent_name, $perl_responder_name, $perl_parent_name);
	my ($basic_xs_file, $basic_pm_file,
		$responder_xs_file, $responder_pm_file, $responder_h_file,
		$responder_cpp_file, $main_h_file, $main_cpp_file);
	
	my @subpath = split /::/, $perl_class_name;
	my $filename = pop @subpath;

	my $xs_folder = File::Spec->catfile($folder, $xs_prefix, @subpath);
	my $pm_folder = File::Spec->catfile($folder, $pm_prefix, @subpath);
	
	mkpath($folder);
	mkpath($xs_folder);
	mkpath($pm_folder);
	
	# if we're the main module, we need to bootstrap
	my $bootstrap = ($perl_module eq $perl_class_name);
	
	if ($bootstrap) {
		# main H file
		my $main_h_filename = File::Spec->catfile($folder, "$filename.h");
		push @ret, 'main_h_filename' => $main_h_filename;
		open $main_h_file, ">$main_h_filename" or die "Unable to create file '$main_h_filename': $!";
		
		print $main_h_file <<TOP;
/*
 * Automatically generated file
 */

TOP
		
		if (my $includes = $bindings->includes) {
			for my $include ($includes->includes) {
				my $file = $include->file;
				print $main_h_file "#include <$file>\n";
			}
			print $main_h_file "\n";
		}
		
		# main CPP file
		my $main_cpp_filename = File::Spec->catfile($folder, "$filename.cpp");
		push @ret, 'main_cpp_filename' => $main_cpp_filename;
		open $main_cpp_file, ">$main_cpp_filename" or die "Unable to create file '$main_cpp_filename': $!";
		
		print $main_cpp_file <<TOP;
/*
 * Automatically generated file
 */
 
#include "$filename.h"

TOP
		
		# basic PM file
		my $basic_pm_filename = File::Spec->catfile($folder, "$filename.pm");
		push @ret, 'basic_pm_filename' => $basic_pm_filename;
		open $basic_pm_file, ">$basic_pm_filename" or die "Unable to create file '$basic_pm_filename': $!";
		
		# basic XS file
		my $basic_xs_filename = File::Spec->catfile($folder, "$filename.xs");
		push @ret, 'basic_xs_filename' => $basic_xs_filename;
		open $basic_xs_file, ">$basic_xs_filename" or die "Unable to create file '$basic_xs_filename': $!";
		
		print $basic_xs_file <<TOP;
/*
 * Automatically generated file
 */

TOP
	}
	else {
		# basic PM file
		my $basic_pm_filename = File::Spec->catfile($pm_folder, "$filename.pm");
		push @ret, 'basic_pm_filename' => $basic_pm_filename;
		open $basic_pm_file, ">$basic_pm_filename" or die "Unable to create file '$basic_pm_filename': $!";
		
		# basic XS file
		my $basic_xs_filename = File::Spec->catfile($xs_folder, "$filename.xs");
		push @ret, 'basic_xs_filename' => $basic_xs_filename;
		open $basic_xs_file, ">$basic_xs_filename" or die "Unable to create file '$basic_xs_filename': $!";
		
		print $basic_xs_file <<TOP;
#
# Automatically generated file
#

TOP
	}
	
	print $basic_pm_file <<TOP;
#
# Automatically generated file
#

package $perl_class_name;
use strict;
use warnings;
TOP
	
	if ($bootstrap) {
		my (@xs_includes, @cpp_includes);
		for my $b (@{ $bindings->bindings }) {
			# don't do self
			next if ($b == $binding);
			
			(my $file = $b->target)=~s!::!/!g;
			
			my @pc = split /::/, $b->target;
			my $name = join('/', @pc);
			
			push @xs_includes, "$xs_prefix/$name.xs";
			
			next unless $b->events;
			
			$pc[-1] = 'Custom' . $pc[-1];
			$name = join('/', @pc);
			
			push @cpp_includes, "$xs_prefix/$name.cpp";
			push @xs_includes, "$xs_prefix/$name.xs";
		}
		
		print $basic_xs_file <<BOOT;
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "$filename.cpp"
BOOT

		for my $file (@cpp_includes) {			
			print $basic_xs_file qq(#include "$file"\n);
		}
		
		print $basic_xs_file "\n";
		
		print $basic_xs_file <<MODINFO;
MODULE = $perl_module	PACKAGE = $perl_class_name

MODINFO
		
		if (@xs_includes) {		
			for my $file (@xs_includes) {			
				print $basic_xs_file qq(INCLUDE: $file\n);
			}
			print $basic_xs_file "\n";
		}
	}
	
	# for non-bootstrap, will emit for the first time
	# for bootstrap, will re-emit in case any includes changed the PACKAGE
	print $basic_xs_file <<MODINFO;
MODULE = $perl_module	PACKAGE = $perl_class_name

MODINFO
	
	my @perl_export;
	
	my $events;
	if ($binding->events) {
		$events = 1;
		
		$cpp_parent_name = $cpp_class_name;
		$cpp_responder_name = 'Custom_' . $cpp_class_name;
		
		$perl_parent_name = $perl_class_name;
		my @pc = split /::/, $perl_class_name;
		$pc[-1] = 'Custom' . $pc[-1];
		$perl_responder_name = join('::', @pc);
		
		# responder PM file
		my $responder_pm_filename = File::Spec->catfile($pm_folder, "Custom$filename.pm");
		push @ret, 'responder_pm_filename' => $responder_pm_filename;
		open $responder_pm_file, ">$responder_pm_filename" or die "Unable to create file '$responder_pm_filename': $!";
		print $responder_pm_file <<TOP;
#
# Automatically generated file
#

package $perl_responder_name;
use strict;
use warnings;

our \$VERSION = $version;
our \@ISA = qw($perl_parent_name);

1;

TOP
		
		# responder XS file
		my $responder_xs_filename = File::Spec->catfile($xs_folder, "Custom$filename.xs");
		push @ret, 'responder_xs_filename' => $responder_xs_filename;
		open $responder_xs_file, ">$responder_xs_filename" or die "Unable to create file '$responder_xs_filename': $!";
		print $responder_xs_file <<TOP;
#
# Automatically generated file
#

MODULE = $perl_module	PACKAGE = $perl_responder_name

# The custom C++ objects keep a copy of the perl object around, so they can
# continue to call methods on it even if the perl script doesn't keep a copy.
# So if the perl script author *wants* the perl object to go out of scope,
# this method gets rid of the C++ object's copy.

TOP
		
		# responder H file
		my $responder_h_filename = File::Spec->catfile($xs_folder, "Custom$filename.h");
		push @ret, 'responder_h_filename' => $responder_h_filename;
		open $responder_h_file, ">$responder_h_filename" or die "Unable to create file '$responder_h_filename': $!";
		
		print $responder_h_file <<TOP;
/*
 * Automatically generated file
 */

class $cpp_responder_name : public $cpp_parent_name {
	public:
TOP
		
		# responder CPP file
		my $responder_cpp_filename = File::Spec->catfile($xs_folder, "Custom$filename.cpp");
		push @ret, 'responder_cpp_filename' => $responder_cpp_filename;
		open $responder_cpp_file, ">$responder_cpp_filename" or die "Unable to create file '$responder_cpp_filename': $!";
		
		print $responder_cpp_file <<TOP;
/*
 * Automatically generated file
 */

#include "Custom$filename.h"

TOP
	}
	
	#
	# constructor
	#
	
	if ($binding->constructors) {
		for my $constructor ($binding->constructors) {
			my $params = $self->parse_params($constructor->params);
			
			$self->generate_xs_method($basic_xs_file,
				function => $constructor,
				cpp_class_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				perl_module => $perl_module,
				params => $params,
				responder => 0,
			);
			
			if ($events) {
				$self->generate_xs_method($responder_xs_file,
					function => $constructor,
					cpp_class_name => $cpp_responder_name,
					perl_class_name => $perl_responder_name,
					cpp_parent_name => $cpp_class_name,
					perl_parent_name => $perl_class_name,
					perl_module => $perl_module,
					params => $params,
					must_not_delete => $binding->{'must-not-delete'} eq 'true',
					responder => 1,
				);
				
				$self->generate_h_method($responder_h_file,
					function => $constructor,
					cpp_class_name => $cpp_responder_name,
					cpp_parent_name => $cpp_class_name,
					params => $params,
				);
				
				$self->generate_cpp_method($responder_cpp_file,
					function => $constructor,
					cpp_class_name => $cpp_responder_name,
					cpp_parent_name => $cpp_class_name,
					perl_class_name => $perl_responder_name,
					params => $params,
				);
			}
		}
	}
	
	#
	# destructor
	#
	
	if ($binding->destructor) {
		my $destructor = $binding->destructor;
		$self->generate_xs_method($basic_xs_file,
			function => $destructor,
			cpp_class_name => $cpp_class_name,
			perl_class_name => $perl_class_name,
			params => {},
			responder => 0,
		);
		
		if ($events) {
			$self->generate_xs_method($responder_xs_file,
				function => $destructor,
				cpp_class_name => $cpp_responder_name,
				perl_class_name => $perl_responder_name,
				cpp_parent_name => $cpp_class_name,
				perl_parent_name => $perl_class_name,
				perl_module => $perl_module,
				params => {},
				responder => 1,
			);
			
			$self->generate_h_method($responder_h_file,
				function => $destructor,
				cpp_class_name => $cpp_responder_name,
				cpp_parent_name => $cpp_class_name,
				params => {},
			);
			
			$self->generate_cpp_method($responder_cpp_file,
				function => $destructor,
				cpp_class_name => $cpp_responder_name,
				cpp_parent_name => $cpp_class_name,
				params => {},
			);
		}
	}
	
	#
	# object methods
	#
	
	if ($binding->methods) {
		for my $method ($binding->methods) {
			my $params = $self->parse_params($method->params);
			
			$self->generate_xs_method($basic_xs_file,
				function => $method,
				cpp_class_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				perl_module => $perl_module,
				params => $params,
				responder => 0,
			);
		}
	}
	
	#
	# event methods
	#
	
	if ($events) {
		for my $event ($binding->events) {
			my $params = $self->parse_params($event->params);
			
			$self->generate_xs_method($responder_xs_file,
				function => $event,
				cpp_class_name => $cpp_responder_name,
				perl_class_name => $perl_responder_name,
				cpp_parent_name => $cpp_class_name,
				perl_parent_name => $perl_class_name,
				perl_module => $perl_module,
				params => $params,
				responder => 1,
			);
			
			$self->generate_h_method($responder_h_file,
				function => $event,
				cpp_class_name => $cpp_responder_name,
				cpp_parent_name => $cpp_class_name,
				params => $params,
			);
			
			$self->generate_cpp_method($responder_cpp_file,
				function => $event,
				cpp_class_name => $cpp_responder_name,
				cpp_parent_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				params => $params,
			);
		}
	}
	
	#
	# static methods
	#
	
	if ($binding->statics) {
		for my $static ($binding->statics) {
			my $params = $self->parse_params($static->params);
			
			$self->generate_xs_method($basic_xs_file,
				function => $static,
				cpp_class_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				params => $params,
				responder => 0,
			);
		}
	}
	
	#
	# plain functions
	#
	
	if ($binding->plains) {
		for my $plain ($binding->plains) {
			my $params = $self->parse_params($plain->params);
			
			$self->generate_xs_method($basic_xs_file,
				function => $plain,
				cpp_class_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				perl_module => $perl_module,
				params => $params,
				responder => 0,
			);
			
			push @perl_export, $plain->name;
		}
	}
	
	#
	# properties
	#
	
	if (my $properties = $binding->properties) {
		for my $property ($properties->properties) {
			$self->generate_xs_property($basic_xs_file,
				property => $property,
				cpp_class_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				perl_module_name => $perl_module,
				responder => 0,
			);
		}
	}
	
	#
	# constants
	#
	
	if (my $constants = $binding->constants) {
		for my $constant ($constants->constants) {
			$self->generate_xs_constant($basic_xs_file,
				constant => $constant,
				cpp_class_name => $cpp_class_name,
				perl_class_name => $perl_class_name,
				perl_module_name => $perl_module,
				responder => 0,
			);
			
			push @perl_export, $constant->name;
		}
	}
	
	# require'd modules
	my @perl_isa;
	if (@perl_export) {
		print $basic_pm_file qq(require Exporter;\n);
		push @perl_isa, 'Exporter';
	}
	if ($bootstrap) {
		print $basic_pm_file qq(require DynaLoader;\n);
		push @perl_isa, 'DynaLoader';
	}
	if (my $perl_isa = $binding->target_inherits) {
		push @perl_isa, $perl_isa;
	}
	print $basic_pm_file "\n";
	
	# package vars
	print $basic_pm_file "our \$VERSION = $version;\n";
	if (@perl_isa) {
		print $basic_pm_file "our \@ISA = qw(", join(' ', @perl_isa), ");\n";
	}
	if (@perl_export) {
		print $basic_pm_file "our \@EXPORT_OK = qw(", join(' ', @perl_export), ");\n";
	}
	print $basic_pm_file "\n";
	
	# bootstrap if necessary
	if ($bootstrap) {
		print $basic_xs_file <<DBG;
MODULE = $perl_module	PACKAGE = ${perl_class_name}::DEBUG

SV*
FETCH(tie_obj)
		SV* tie_obj;
	CODE:
		RETVAL = newSViv(debug_level);
	OUTPUT:
		RETVAL

void
STORE(tie_obj, value)
		SV* tie_obj;
		SV* value;
	CODE:
		debug_level = SvIV(value);
		
MODULE = $perl_module	PACKAGE = $perl_class_name

BOOT:
	set_up_debug_sv("${perl_class_name}::DEBUG");

DBG

		print $basic_pm_file "bootstrap $perl_module \$VERSION;\n\n";
	}
	
	# end true
	print $basic_pm_file "1;\n";
	
	close $basic_pm_file;
	close $basic_xs_file;
	if ($events) {
		print $responder_h_file <<END;
		object_link_data* perl_link_data;
}; // $cpp_class_name
END

		close $responder_pm_file;
		close $responder_xs_file;
		close $responder_h_file;
		close $responder_cpp_file;
	}
	
	if ($bootstrap) {
		$self->generate_utility_h_code($main_h_file);
		close $main_h_file;
		
		$self->generate_utility_cpp_code($main_cpp_file);
		close $main_cpp_file;
	}
	
	return @ret;
}

1;
