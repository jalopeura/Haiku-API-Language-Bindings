package PodViewer::PodView;
use strict;
our @ISA = qw(Haiku::TextView);

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new(@_);
	
	return $self;
}

sub Display {
	my ($self, $text) = @_;

#print "Inserting $text\n";
	$self->Insert($text);
	$self->Invalidate;
}

1;
