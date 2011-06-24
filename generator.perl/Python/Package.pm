package Python::Package;
use File::Spec;
use File::Path;
use Python::Types;
use Python::PyModule;
require Python::UtilityCodeGenerator;
use strict;
our @ISA = qw(Python::PyModule);

# A Library is the main PyModule in a group, the one for which the user
# loads the library (via import); loading it also loads the other PyModules

sub new {
	my ($class, $bindings, $parent) = @_;
	
	my $self = bless {
		modules => [],
		parent  => $parent,
	}, $class;
	
	# need to create this now, in order to pass it to packages
	my $types = new Python::Types;
	
	for my $binding ($bindings->bindings) {
		# if we have any of the following, we need a PyModule
		#    plain functions, constants
		# also if we're going to need a PyType, we need a PyModule to get at it
		if ($binding->plains or $binding->constants or $binding->constructors) {
			my $module = new Python::PyModule($self, $binding, $types);
			if ($binding->target eq $bindings->name) {
				# copy package into self
				my @keys = keys %$module;
				@{$self}{@keys} = @{$module}{@keys};
			}
			else {
				push @{ $self->{modules} }, $module;
			}
		}
	}
	
	# register defined types
	for my $btypes ($bindings->types_collection) {
		for my $type ($btypes->types) {
			my @target = split /::/, $type->target;
			my $target = join('.', @target, $target[-1]);
#print "Registering type from $type: $type->{name}/$type->{builtin}/$target\n";
			$types->register_type(
				$type->name,
				$type->builtin,
				$target,
			);
		}
	}
	
	# register the types we've just created
	for my $child (@{ $self->{children} }) {
		if (my $cpp_class = $child->{cpp_class}) {
#print "Registering type from $child: $cpp_class*/$child->{type}/$child->{name}\n";
			$types->register_type(
				"$cpp_class*",
				$child->{type},
				$child->{name},
			);
		}
	}
	for my $module (@{ $self->{modules} }) {
		for my $child (@{ $module->{children} }) {
			if (my $cpp_class = $child->{cpp_class}) {
#print "Registering type from $child: $cpp_class*/$child->{type}/$child->{name}\n";
				$types->register_type(
					"$cpp_class*",
					$child->{type},
					$child->{name},
				);
			}
		}
	}
	
	if (my @includes = $bindings->includes_collection) {
		my @inc;
		for my $includes (@includes) {
			for my $include ($includes->includes) {
				push @inc, $include->file;
			}
		}
		$self->{includes} = \@inc;
	}
	
	# if we had no binding named the same as ourself we need to do some more
	unless ($self->{name}) {
		$self->{types} ||= $types;
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
	my @path = ($self->{parent}->resolve_path($caller), $self->{filename});
	return @path;
}

sub open_files {
	my ($self, $folder) = @_;
	
	my @subpath = split /\./, $self->{name};
	my $filename = pop @subpath;
	
	mkpath($folder);
	
	# PY file
#	my $py_filename = File::Spec->catfile($folder, "$filename.py");
#	open $self->{pyh}, ">$py_filename" or die "Unable to create file '$py_filename': $!";
	
	my $c_filename = File::Spec->catfile($folder, "$filename.cc");
	open $self->{ch}, ">$c_filename" or die "Unable to create file '$c_filename': $!";
	
	$self->{filename} = $filename;
}

sub generate {
	my ($self, $folder) = @_;
	
	# generate our modules
	for my $module (@{ $self->{modules} }) {
		$module->generate($folder);
	}
	
	# generate ourself (with children)
	$self->SUPER::generate($folder);
	
	# no name member means we had no binding named the same as ourself
	# this means we're just being used to bundle other packages
	# so no utility files are necessary
	if ($self->{name}) {
		$self->generate_h_code($folder);
		$self->generate_utility_h_code($folder);
		$self->generate_utility_cpp_code($folder);
	}
}

sub generate_h_code {
	my ($self, $folder) = @_;
	
	my $filename = File::Spec->catfile($folder, "$self->{filename}.h");
	open my $fh, ">$filename" or die "Unable to create file '$filename': $!";
	
	print $fh <<TOP;
/*
 * Automatically generated file
 */

TOP
	
	if ($self->{includes}) {
		for my $file (@{ $self->{includes} }) {
			print $fh "#include <$file>\n";
		}
		print $fh "\n";
	}
	
	print $fh <<DEFS;
static PyObject* $self->{filename}Error;

DEFS
		
	# we need to predeclare responder classes;
	my @predeclare;
	for my $child (@{ $self->{children} }) {
		next unless $child->isa('Python::ResponderPyType');
		push @predeclare, $child->{cpp_class};
	}
	for my $module (@{ $self->{modules} }) {
		for my $child (@{ $module->{children} }) {
			next unless $child->isa('Python::ResponderPyType');
			push @predeclare, $child->{cpp_class};
		}
	}
	if (@predeclare) {
		print $fh "// predeclare necessary class(es)\n";
		for my $class (@predeclare) {
			print $fh "class $class;\n"
		}
		print $fh "\n";
	}
	
	$self->{types}->write_typeobject_defs($fh);
	
	close $fh;
}

#
# overridden code-generation functions
#

sub generate_c_preamble {
	my ($self) = @_;
	
	my $fh = $self->{ch};
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
	
	# determine includes and constants
	my (@includes, @constant_defs);
	for my $child (@{ $self->{children} }) {
		if ($child->isa('Python::ResponderPyType')) {
			push @includes, $child->{cpp_include};
		}
		push @includes, $child->{c_include};
		push @constant_defs, @{ $child->{constant_defs} };
	}
	for my $module (@{ $self->{modules} }) {
		for my $child (@{ $module->{children} }) {
			if ($child->isa('Python::ResponderPyType')) {
				push @includes, $child->{cpp_include};
			}
			push @includes, $child->{c_include};
			push @constant_defs, @{ $child->{constant_defs} };
		}
		# add module after adding children
		push @includes, $module->{c_include};
	}
	
	for my $file (@includes) {
		print $fh qq(#include "$file"\n);
	}
	print $fh "\n";
	
	for my $def (@constant_defs) {
		print $fh qq($def\n);
	}
	print $fh "\n";
}

sub generate_c_postamble {
	my ($self) = @_;
	
	my $fh = $self->{ch};
	my $filename = $self->{filename};
	my $module_name = "${filename}_module";
	
	(my $name = $self->{name})=~s/\./_/g; $name .= '_';
	
	$self->SUPER::generate_c_postamble;
	
	my (%module_names, @module_defs, @module_code);
	($module_defs[0], $module_code[0]) = $self->generate_module_init($self);
	for my $module (@{ $self->{modules} }) {
		my ($defs, $code) = $self->generate_module_init($module);
		$module_names{ $module->{name} } = 1;
		push @module_defs, $defs;
		push @module_code, $code;
	}
	
	# make any necessary empty modules to prevent "name not defined" errors
	my (@parent_defs, @parent_methods, @parent_code);
	for my $m (sort keys %module_names) {
		my @m = split /\./, $m;
		pop @m;
		for my $i (0..$#m) {
			my $module_name = join('.', @m[0..$i]);
			next if $module_names{$module_name};
			$module_names{$module_name} = 1;
			
			my @p = @m[0..$i];
			my $full_string = join('.', @p);
			my $module_string = pop @p;
			my $parent_name = join('.', @p);
			
			$module_name=~s/\./_/g;
			my $methods_name = $module_name . '_methods';
			$module_name .= '_module';
			
			if ($parent_name) {
				$parent_name=~s/\./_/g;
				$parent_name .= '_module';
			}
			else {
				$parent_name = 'python_main';
			}

			push @parent_defs, qq(\tPyObject* $module_name = PyImport_AddModule("$full_string");\n);
			
#			push @parent_methods, <<METHODS;
#static PyMethodDef ${methods_name}[] = {
#	{NULL} /* Sentinel */
#};
#
#METHODS

#push @parent_code, <<CODE;
#	$module_name = Py_InitModule("$full_string", $methods_name);
#	Py_INCREF($module_name);
#	PyModule_AddObject($parent_name, "$module_string", $module_name);
#	
#CODE
		}
	}
	
	print $fh @parent_methods;
	
	print $fh <<INIT;
/*
 * Some of the base classes may be defined in other packages, which means we don't
 * have access to them here. We eval a Python string to get access to the base type.
 * This means any base types need to be added to their containing modules before
 * this function is called. This means the user must load modules containing base
 * classes before loading the modules in this package.
 *
 * For the sake of simplicity, even base classes that are defined in this package
 * are set using this function, so it must be called after all our own types have
 * been added to their containing modules.
 */
PyMODINIT_FUNC
init$filename()
{
	PyObject* python_main = PyImport_AddModule("__main__");
	PyObject* main_dict = PyModule_GetDict(python_main);
//	PyObject* holder;
INIT
	
	print $fh @parent_defs;
	
	for my $def (@module_defs) {
		print $fh "\t$def\n";
	}
	
	print $fh "\n";

	print $fh @parent_code;
	
	for my $code (@module_code) {
		print $fh $code;
	}
	
	(my $modname = $self->{name})=~s/\./_/g; $modname .= '_module';
	
	print $fh <<END;
//printf("About to set up error object\\n");
	// exception object
	${filename}Error = PyErr_NewException("$self->{name}.error", NULL, NULL);
    Py_INCREF(${filename}Error);
    PyModule_AddObject($modname, "error", ${filename}Error);
//printf("Successfully set up error object\\n");
} //init$filename

END
}

sub generate_module_init {
	my ($self, $module) = @_;
	
	(my $name = $module->{name})=~s/\./_/g; $name .= '_';
	my $module_name = "${name}module";
	
	my $def = "PyObject* $module_name;";
	my $code = <<CODE;
//printf("About to init $module->{name}\\n");
	// $module->{name}: module
    $module_name = Py_InitModule("$module->{name}", ${name}methods);
    if ($module_name == NULL)
        return;
//printf("Successfully init'ed $module->{name}\\n");
		
CODE
	
	# if we're not the module being loaded, we need to
	# manually add ourselves to our parent module
	if ($self != $module) {
		my @p = split /\./, $module->{name};
		my $subname = pop @p;
		my $parent_name;
		if (@p) {
			$parent_name = join('_', @p, 'module');
		}
		else {
			$parent_name = 'python_main';
		}

#		(my $parent_name = $self->{name})=~s/\./_/g; $parent_name .= '_module';
		$code .= <<ADD;	
	Py_INCREF($module_name);
	PyModule_AddObject($parent_name, "$subname", $module_name);
	
ADD
	}
	
	if (@{ $module->{children} }) {
		$code .= "\t// $module->{name}: types (classes)\n";
		for my $child (@{ $module->{children} }) {
			my @cname = split /\./, $child->{name};
			my $cname = join('_', @cname, 'Type');
			
			if ($child->{python_parent}) {
				$code .= <<INHERIT;
//	holder = PyRun_String("$child->{python_parent}", Py_eval_input, main_dict, main_dict);
//	$cname.tp_bases = PyTuple_Pack(1, holder);
	$cname.tp_base = (PyTypeObject*)PyRun_String("$child->{python_parent}", Py_eval_input, main_dict, main_dict);
	
INHERIT
			}
			
			$code .= <<TYPE;
	if (PyType_Ready(&$cname) < 0)
		return;
	Py_INCREF(&$cname);
	PyModule_AddObject($module_name, "$cname[-1]", (PyObject*)&$cname);
	
TYPE
		}
	}
	
	if (@{ $module->{constant_code} }) {
		$code .= "\t// $module->{name}: constants\n";
		for my $i (0..$#{ $module->{constant_code} }) {
			my $line = $module->{constant_code}[$i];
			$line=~s/\%MODULE\%/$module_name/;
			$code .= "\t$line\n";
		}
	}
	
	return ($def, $code);
}

1;
