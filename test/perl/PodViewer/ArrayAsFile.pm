package ArrayAsFile;
use strict;

use constant POS_IN_FILE => 0;
use constant LINE_NUMBER => 1;
use constant POS_IN_LINE => 2;

sub TIEHANDLE {
	my ($class, $aref) = @_;
	
	my $self = bless {
		data => $aref,
		data_offsets => [],
	}, $class;
	
	my $offset;
	for my $i (0..$#$aref) {
		$self->{data_offsets}[$i] = $offset;
		$offset += length($aref->[$i]);
	}
	$self->{size} = $offset;
	$self->{position} = 0;
	
	return $self;
}

sub TELL {
	my ($self) = @_;
	return $self->{position};
}

sub SEEK {
	my ($self, $position, $whence) = @_;
	
	if ($whence == 0) {	# START + $position
		$self->{position} = $position;
	}
	
	if ($whence == 1) {	# CURRENT + position
		$self->{position} += $position;
	}
	
	if ($whence == 2) {	# END + $position
		$self->{position} = $self->{size} + $position;
	}
}

sub get_line_and_offset {
	my ($self) = @_;
	
	my $line = 0;
	while ($line <= $#{ $self->{data} }) {
		last if ($self->{data_offsets}[$line] > $self->{position});
		$line++;
	}
	$line--;
	
	my $offset = $self->{position} - $self->{data_offsets}[$line];
	
	return ($line, $offset);
}

sub READ {
	my($self, undef, $len, $offset) = @_;
	
	if ($self->{position} >= $self->{size}) {
		return undef;
	}
	
	my ($data_line, $data_offset) = $self->get_line_and_offset;
	
	# get the rest of the current line
	my $data = $self->{data}[$data_line];
	if ($data_offset) {
		substr($data, 0, $data_offset, '');
	}
	
	# if they wanted more, give them more
	while (length($data) < $len) {
		$data .= $self->{data}[++$data_line];
		last if ($data_line >= $#{ $self->{data} });
	}
	
	# if we got too much, chop off the end
	if (length($data) > $len) {
		substr($data, $len, length($data), '');
	}
	
	$len = length($data);	# length actually read may be less than requested
	$self->{position} += $len;
	$_[1] = $data;
	return $len;
}

sub READLINE {
	my ($self) = @_;
	
	if ($self->{position} >= $self->{size}) {
		return wantarray ? () : undef;
	}
	
	my ($data_line, $data_offset) = $self->get_line_and_offset;
	
	# get the rest of the current line
	my $data = $self->{data}[$data_line];
	if ($data_offset) {
		substr($data, 0, $data_offset, '');
	}
	
	if (wantarray) {
		my @data = ($data);
		while ($data_line <= $#{ $self->{data} }) {
			push @data, $self->{data}[++$data_line];
		}
		$self->{position} = $self->{size};
		return @data;
	}
	
	$self->{position} += length($data);
	return $data;
}

sub CLOSE {}

1;
