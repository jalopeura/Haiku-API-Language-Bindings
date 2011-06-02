package Perl::Params;
use strict;

sub new {
	my ($class, @init) = @_;
	my $self = bless {
		data_aref => [],
		data_href => {},
		cache => {},
	}, $class;
	for my $p (@init) {
		$self->parse($p);
	}
	return $self;
}

sub parse {
	my ($self, $p, $cpp_return) = @_;
	
	# check the action
	my $ac = $p->{action};
	$cpp_return or do {
		$ac eq 'input' or $ac eq 'output' or $ac eq 'error'
			or $ac=~/^(count|length)\[.+?\]$/
			or die "Unrecognized action: $ac";
	};
	
	$self->{data_href}{ $p->{name} } ||= {};
	my $href = $self->{data_href}{ $p->{name} };
	for my $k (keys %$p) {
		$href->{$k} = $p->{$k};
	}
	if ($cpp_return) {
		$href->{action} = 'output';
		$href->{return} = $cpp_return;
	}
	
	if ($p->{action}=~/^(count|length)\[(.+?)\]$/) {
		my $mod = $1;
		my $target = $2;
		$self->{data_href}{$target} ||= {};
		my $target_href = $self->{data_href}{$target};
		$target_href->{$mod} = $href;
	}
	
	push @{ $self->{data_aref} }, $href;
	$self->{data_href}{ $p->{name} } = $href;
	%{ $self->{cache} } = ();
}

sub h_params {
	my ($self) = @_;
	unless ($self->{cache}{h_params}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			next if $p->{return};
			$ret .= "$p->{type} $p->{name}";
			if ($p->{default}) {
				$ret .= " = $p->{default}";
			}
			$ret .= ', ';
		}
		$ret=~s/, $//;
		$self->{cache}{h_params} = $ret;
	}
	return $self->{cache}{h_params};
}

sub cpp_params {
	my ($self) = @_;
	unless ($self->{cache}{cpp_params}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			next if $p->{return};
			$ret .= "$p->{type} $p->{name}, ";
		}
		$ret=~s/, $//;
		$self->{cache}{cpp_params} = $ret;
	}
	return $self->{cache}{cpp_params};
}

sub xs_inputs {
	my ($self) = @_;
	unless ($self->{cache}{xs_inputs}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			if ($p->{action} eq 'input') {
				$ret .= "$p->{name}, ";
			}
		}
		$ret=~s/, $//;
		$self->{cache}{xs_inputs} = $ret;
	}
	return $self->{cache}{xs_inputs};
}

sub xs_input_defs {
	my ($self) = @_;
	unless ($self->{cache}{xs_input_defs}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			if ($p->{action} eq 'input') {
				$ret .= "\t\t$p->{type} $p->{name}";
				if ($p->{default}) {
					$ret .= " = $p->{default}";
				}
				$ret .= ";\n";
			}
		}
		$ret=~s/\n$//;
		$self->{cache}{xs_input_defs} = $ret;
	}
	return $self->{cache}{xs_input_defs};
}

sub xs_error_defs {
	my ($self) = @_;
	unless ($self->{cache}{xs_error_defs}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			if ($p->{action} eq 'error') {
				$ret .= "\t\t$p->{type} $p->{name}";
				if ($p->{default}) {
					$ret .= " = $p->{default}";
				}
				$ret .= ";\n";
			}
		}
		$ret=~s/\n$//;
		$self->{cache}{xs_error_defs} = $ret;
	}
	return $self->{cache}{xs_error_defs};
}

sub xs_cpp_inputs {
	my ($self) = @_;
	unless ($self->{cache}{xs_cpp_inputs}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			next if $p->{return};
			$ret .= "$p->{name}, ";
		}
		$ret=~s/, $//;
		$self->{cache}{xs_cpp_inputs} = $ret;
	}
	return $self->{cache}{xs_cpp_inputs};
}

sub xs_output_list {
	my ($self) = @_;
	unless ($self->{cache}{xs_output_list}) {
		my $ret = [];
		for my $p (@{ $self->{data_aref} }) {
			if ($p->{action} eq 'output') {
				push @$ret, $p;
			}
		}
		$self->{cache}{xs_output_list} = $ret;
	}
	return $self->{cache}{xs_output_list};
}

sub xs_error_list {
	my ($self) = @_;
	unless ($self->{cache}{xs_error_list}) {
		my $ret = [];
		for my $p (@{ $self->{data_aref} }) {
			if ($p->{action} eq 'error') {
				push @$ret, $p;
			}
		}
		$self->{cache}{xs_error_list} = $ret;
	}
	return $self->{cache}{xs_error_list};
}

sub perl_event_params {
	my ($self) = @_;
	unless ($self->{cache}{perl_event_params}) {
		my ($ret, $n);
		for my $p (@{ $self->{data_aref} }) {
			next unless $p->{action} eq 'input';
			
			# builtin types
			if ($p->{passback} eq 'builtin') {
				# here handle builtin types
				$ret .= qq(\t//$p->{name}_sv = ... do a builtin type here\n);
				$n++;
			}
			# objects
			elsif ($p->{passback}) {
				my $must_not_delete = $p->{'must-not-delete'} ? 'true' : 'false';
				$ret .= qq(\t$p->{name}_sv = sv_2mortal(create_perl_object((IV)$p->{name}, "$p->{passback}", $must_not_delete));\n);
				$n++;
			}
			else {
				die "No passback value provided";
			}
			$ret .= qq(\tPUSHs($p->{name}_sv);\n);
		}
		$ret=~s/\n$//;
		$self->{cache}{perl_event_params} = $ret;
		$self->{cache}{perl_event_param_count} = $n;
	}
	return $self->{cache}{perl_event_params};
}

sub perl_event_param_count {
	my ($self) = @_;
	unless ($self->{cache}{perl_event_param_count}) {
		$self->perl_event_params;
	}
	return $self->{cache}{perl_event_param_count};
}

sub perl_event_param_defs {
	my ($self) = @_;
	unless ($self->{cache}{perl_event_param_defs}) {
		my $ret;
		for my $p (@{ $self->{data_aref} }) {
			next unless $p->{action} eq 'input';
			
			$ret .= qq(\tSV* $p->{name}_sv;\n);
		}
		$ret=~s/\n$//;
		$self->{cache}{perl_event_param_defs} = $ret;
	}
	return $self->{cache}{perl_event_param_defs};
}

1;
