package Python::Package;
use File::Spec;
use File::Path;
use Python::Bundle;
use Python::Class;
use Python::ResponderClass;
use Python::Include;
use Python::Link;
use Python::Types;
require Python::UtilityCodeGenerator;
use strict;
our @ISA = qw(Bindings Python::BaseObject);

sub new {
	my ($class, $bindings, $parent) = @_;
	my $self = $class->upgrade($bindings->source_type_prefix, $bindings);
	
	$self->{_parent} = $parent;
	
	$self->{name}=~s/::/./g;
	
	if ($self->has('classes')) {
		my @classes = $self->classes;
		$self->{classes} = [];
		$self->{constants} = [];
		for my $class (@classes) {
			if ($class->has('functions') or $class->has('properties')) {
				push @{ $self->{classes} }, $class;	
				if ($class->has('functions') and $class->functions->had('events')) {
					push @{ $self->{classes} },
						Python::ResponderClass->upgrade($bindings->source_type_prefix, $class);
				}
			}
			elsif ($class->has('constants')) {
				push @{ $self->{constants} }, $class->constants->constants;
			}
		}
	}
	
	$self->propagate_value('package_name', $self->name);
	
	$self->{types} ||= Python::Types->create_empty;
	$self->propagate_value('types', $self->types);
	
	if ($self->has('classes')) {
		for my $class ($self->classes) {
			if ($class->has('cpp_name')) {
				my $name = $class->cpp_name;
				my $type = $class->is_responder ? 'responder' : 'object';
				my $target = $class->python_name;
				$self->types->register_type($name, $type, $target);
				
				$name .= '*'; $type .= '_ptr';
				$self->types->register_type($name, $type, $target);
			}
		}
	}
	
	return $self;
}

sub resolve_filename {
	my ($self, $caller) = @_;
	if ($self == $caller) {
		return $self->{filename};
	}
	my @path = $self->resolve_path($caller);
	return File::Spec->catfile(@path, $self->{filename});
}

sub resolve_path {
	my ($self, $caller) = @_;
	if ($self == $caller) {
		return ();
	}
	my @path = ($self->{_parent}->resolve_path($caller), $self->{filename});
	return @path;
}

sub add_functions {
	my ($self, $plains);
	$self->{functions} ||= [];
	push @{ $self->{functions} }, $plains;
}

sub add_method_table_entry {
	my ($self, $python_name, $function_pointer, $flags, $doc) = @_;
	push @{ $self->{method_table} }, qq({"$python_name", (PyCFunction)$function_pointer, $flags, "$doc"});
}

sub generate {
	my ($self, $folder, $ext_prefix) = @_;
	
	# generate packages before self, so packages can report filenames
	if ($self->has('classes')) {
		for my $class ($self->classes) {
			$class->generate($folder, $ext_prefix);
		}
	}

	# if we have classes or constants, we're a real binding and
	# we need utility files; otherwise we're just a bundle
	if ($self->has('classes') or $self->has('constants')) {
		$self->open_files($folder, $ext_prefix);
		$self->generate_preamble;
		$self->generate_body;
		$self->generate_postamble;
		$self->close_files;
		
		$self->generate_utility_h_code($folder);
		$self->generate_utility_cpp_code($folder);
	}
}

sub open_files {
	my ($self, $folder, $ext_prefix) = @_;
	
	my @subpath = split /\./, $self->name;
	my $filename = pop @subpath;
	
	mkpath($folder);
	
	# PY file
#	my $py_filename = File::Spec->catfile($ext_folder, "$filename.py");
#	open $self->{pyh}, ">$py_filename" or die "Unable to create file '$py_filename': $!";
	
	# H file
	my $h_filename = File::Spec->catfile($folder, "$filename.h");
	open $self->{hh}, ">$h_filename" or die "Unable to create file '$h_filename': $!";
	
	# CC file
	my $cc_filename = File::Spec->catfile($folder, "$filename.cc");
	open $self->{cch}, ">$cc_filename" or die "Unable to create file '$cc_filename': $!";
	
	$self->{filename} = $filename;
}

sub generate_preamble {
	my ($self) = @_;
	
	$self->generate_py_preamble;
	$self->generate_h_preamble;
	$self->generate_cc_preamble;
}

sub generate_body {
	my ($self) = @_;
	
	$self->generate_py_body;
	$self->generate_h_body;
	$self->generate_cc_body;
}

sub generate_postamble {
	my ($self) = @_;
	
	$self->generate_py_postamble;
	$self->generate_h_postamble;
	$self->generate_cc_postamble;
}

sub close_files {
	my ($self) = @_;
#	close $self->{pyh};
	close $self->{hh};
	close $self->{cch};
}

#
# PY-specific sections
#

sub generate_py_preamble {}	# nothing to do
sub generate_py_body {}	# nothing to do
sub generate_py_postamble {}	# nothing to do

#
# H-specific sections
#

sub generate_h_preamble {
	my ($self) = @_;
	
	my $fh = $self->hh;
	my $filename = $self->{filename};
	
	print $fh <<TOP;
/*
 * Automatically generated file
 */

TOP
	
	# include standard files
	if ($self->has('include')) {
		for my $file ($self->include->files) {
			print $fh qq(#include <), $file->name, qq(>\n);
		}
		print $fh "\n";
	}
	
	print $fh <<DEFS;
static PyObject* python_main;
static PyObject* main_dict;
static PyObject* ${filename}Error;

DEFS
	
	# predeclare responder classes
	if ($self->has('classes')) {
		for my $class ($self->classes) {
			next unless $class->is_responder;
			
			print $fh 'class ', $class->cpp_name, ";\n";
		}
		print $fh "\n";
	}
}

sub generate_h_body {}	# nothing to do

sub generate_h_postamble {
	my ($self) = @_;
	
	if ($self->has('types')) {
		$self->types->write_object_types($self->hh);
	}
}

#
# CC-specific sections
#

sub generate_cc_preamble {
	my ($self) = @_;
	
	my $fh = $self->cch;
	my $filename = $self->{filename};
	
	print $fh <<TOP;
/*
 * Automatically generated file
 */

extern "C" {
#include <Python.h>
}

#include "$filename.h"
#include "${filename}Utils.cpp"
TOP
	
	# include extension files
	if ($self->has('classes')) {
		for my $class ($self->classes) {
			if ($class->is_responder) {
				print $fh qq(#include "), $class->cpp_include, qq("\n);
			}
			print $fh qq(#include "), $class->cc_include, qq("\n);
		}
		print $fh "\n";
	}
}

sub generate_cc_body {
	my ($self) = @_;
	
	(my $python_module_prefix = $self->name)=~s/\./_/g;
	
	if ($self->has('functions')) {
		for my $f ($self->functions) {
			$f->generate;
		}
	}
	
	my $fh = $self->cch;
	
	# methods table
	my $method_table = "${python_module_prefix}_methods";
	print $fh qq(static PyMethodDef ${method_table}[] = {\n);
	if ($self->has('method_table')) {
		for my $def (@{ $self->{method_table} }) {
			print $fh "\t$def,\n";
		}
	}
	print $fh "\t{NULL} /* Sentinel */\n};\n\n";
}

sub generate_cc_postamble {
	my ($self) = @_;
	
	my $fh = $self->cch;
	my $filename = $self->{filename};
	my $module_name = "${filename}_module";
	
	(my $module_prefix = $self->name)=~s/\./_/g; $module_prefix .= '_';
	
	print $fh <<TOP;
PyMODINIT_FUNC
init$filename()
{
TOP
	
	# determine the module names we'll need, including the package
	my @module_names = ($module_name);
	if ($self->has('classes')) {
		for my $class ($self->classes) {
			next unless $class->has('constants');
			(my $class_name = $class->python_name)=~s/\./_/g; $class_name .= 'Constants_module';
			push @module_names, $class_name;
		}
	}
	for my $m (@module_names) {
		print $fh qq(\tPyObject* $m;\n)
	}
	print $fh "\t\n";
	
	# set some globals
	print $fh <<GLOBALS;
	python_main = PyImport_AddModule("__main__");
	main_dict = PyModule_GetDict(python_main);

GLOBALS
	
	# init the package module
	my $python_name = $self->name;
	print $fh <<INIT;
	// $python_name: package module
	$module_name = Py_InitModule("$python_name", ${module_prefix}methods);
	if ($module_name == NULL)
		return;
	
	// add us immediately (ordinarily we're not added until this
	// function returns, but we need it before then
//	Py_INCREF($module_name);
//	PyModule_AddObject(python_main, "$python_name", $module_name);

INIT
	
	my @n = split /\./, $self->name;
	if (@n > 1) {
		my $base_name = pop @n;
		my $parent_name = join('.', @n);
		my $parent_module = join('_', @n, 'module');
		
		print $fh <<PARENT;
	// add us to parent
	PyObject* $parent_module = PyImport_AddModule("$parent_name");
	Py_INCREF($module_name);
	PyModule_AddObject($parent_module, "$base_name", $module_name);
	
PARENT
	}
	
	# for each class, add the class to the module
	# if there are constants, init the constant module
	# and add the constants to it
	if ($self->has('classes')) {
		# do all the classes first, then iterate through them again
		# to do the constants (a constant may require a type to be
		# be defined, so we have to define all types first)
		for my $class ($self->classes) {
			my @n = split /\./, $class->python_name;
			my $init = $class->initfunc_name;
			my $type = $class->pytype_name;
			print $fh "\t// $class->{python_name}: class\n";
			
			if ($class->has('python_parent')) {
				my @p = split /\s+/, $class->{python_parent};
				for my $p (@p) {
					$p=~s/\./_/g;
					print $fh "\t//Py_INCREF(&$p\_PyType);	// base class\n";
				}
			}
			
			my $cn = pop @n;
			
			my $parent_module = join('_', @n, 'module');
			
			print $fh <<CLASS;
	$init(&$type);
	if (PyType_Ready(&$type) < 0)
		return;
	Py_INCREF(&$type);
	PyModule_AddObject($parent_module, "$cn", (PyObject*)&$type);
	
CLASS
		}
		
		# now for the constants
		for my $class ($self->classes) {
			if ($class->has('constants') and $class->constants->has('constants')) {
				my @n = split /\./, $class->python_name;
				my $cn = pop @n;
				my $parent_module = join('_', @n, 'module');
				
				print $fh "\t// $cn: constants (in their own module)\n";
				my @n = split /\./, $class->python_name;
				$n[-1] .= 'Constants';
				my $module_object_name = join('_', @n, 'module');
				my $method_object_name = $class->constants_module_method_table_name;
				my $python_module_name = join('.', @n);
				(my $class_module = $class->python_name)=~s/\./_/g; $class_module .= 'Constants_module';
				print $fh <<MODULE;
	$module_object_name = Py_InitModule("$python_module_name", $method_object_name);
	if ($module_object_name == NULL)
		return;
	Py_INCREF($module_object_name);
	PyModule_AddObject($parent_module, "$n[-1]", $module_object_name);
	
MODULE
				my $module_object_prefix = join('_', @n, '');
				
				# if the class has constants, add them here
				if ($class->has('constant_defs')) {
					for my $def ($class->constant_defs) {
						print $fh qq(\t$def\n)
					}
					print $fh "\n";
				}
				if ($class->has('constant_code')) {
					for my $line ($class->constant_code) {
						print $fh qq(\t$line\n)
					}
				}
			}
		}
	}
	
	print $fh <<END;
	// exception object
	${filename}Error = PyErr_NewException((char*)"$self->{name}.error", NULL, NULL);
    Py_INCREF(${filename}Error);
    PyModule_AddObject($module_name, "error", ${filename}Error);
} //init$filename

END
}

1;
