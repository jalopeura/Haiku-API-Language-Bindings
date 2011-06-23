package Perl::Package;
use strict;

sub parse_params {
	my ($self, $function) = @_;
	
	my @params;
	for my $params ($function->params_collection) {
		push @params, $params->params;
	}
	push @params, $function->returns;
	
	my (@cpp_inputs, $cpp_output, %xs_params, $xs_retval, @xs_inputs, @xs_outputs, @xs_errors);
	
	for my $param (@params) {
		my $name = $param->{name};
		my $type = $param->{type};
#		my $perltype = "PERLTYPE($param->{type})";	# placeholder
		my $default = $param->{default};
		my $action = $param->{action};
		
		if ($param->isa('Return')) {
			$name ||= 'retval';
			
			$cpp_output = {
				name => $name,
				type => $type,
				must_not_delete => $param->{must_not_delete},
			};
			
			$xs_params{$name} ||= {};
			$xs_params{$name}{name} = $name;
			$xs_params{$name}{type} = $type;
			$xs_retval = $xs_params{$name};
		}
		else {
			push @cpp_inputs, {
				name => $name,
				type => $type,
				deref => $param->{deref},
			};
			
			if ($action eq 'input') {
				$xs_params{$name} ||= {};
				$xs_params{$name}{name} = $name;
				$xs_params{$name}{type} = $type;
				$xs_params{$name}{default} = $default;
				$xs_params{$name}{deref} = $param->{deref};
				$xs_params{$name}{must_not_delete} = $param->{'must-not-delete'};
				$xs_params{$name}{passback} = $param->{passback};
				push @xs_inputs, $xs_params{$name};
			}
			elsif ($action eq 'output') {
				$xs_params{$name} ||= {};
				$xs_params{$name}{name} = $name;
				$xs_params{$name}{type} = $type;
				$xs_params{$name}{default} = $default;
				$xs_params{$name}{deref} = $param->{deref};
				$xs_params{$name}{must_not_delete} = $param->{'must-not-delete'};
				push @xs_outputs, $xs_params{$name};
			}
			elsif ($action eq 'error') {
				$xs_params{$name} ||= {};
				$xs_params{$name}{name} = $name;
				$xs_params{$name}{type} = $type;
				$xs_params{$name}{deref} = $param->{deref};
				$xs_params{$name}{success} = $param->{success};
				push @xs_errors, $xs_params{$name};
			}
			elsif ($action=~/^(length|count)\[(.+?)\]$/) {
				my $key = $1;
				my $ref = $2;
				$xs_params{$ref} ||= {};
				$xs_params{$ref}{$key} = {
					name => $name,
					type => $type,
				};
			}
			else {
				die "Unknown action in params: $action ($param)" . join(':::', %{ $param->{element}{attrs} });
			}
		}
	}
	
	return {
		cpp_inputs => \@cpp_inputs,
		cpp_output => $cpp_output,
		xs_retval => $xs_retval,
		xs_inputs => \@xs_inputs,
		xs_outputs => \@xs_outputs,
		xs_errors => \@xs_errors,
	};
}

1;
