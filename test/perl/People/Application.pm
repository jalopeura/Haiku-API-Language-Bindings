package People::Application;
use Haiku::SupportKit;
use Haiku::ApplicationKit;
use Haiku::StorageKit;
use People::ListWindow;
use People::PersonWindow;
use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use Haiku::NodeMonitor qw(:opcodes);
use strict;
our @ISA = qw(Haiku::CustomApplication);

sub new {
	my ($class, @args) = @_;
	
	my $self = $class->SUPER::new("application/x-people", @args);
	
#	$self->{queries} = [];
	$self->{people} = {};

	$self->{listwindow} = new People::ListWindow(
		my $r = new Haiku::Rect(50,50,250,550),	# frame
		"People",	# title
		B_TITLED_WINDOW,	# type
		B_QUIT_ON_WINDOW_CLOSE,	# flags
	);
	
	$self->initialize_queries;
	
	$self->{listwindow}->Show;
	
	return $self;
}

sub initialize_queries {
	my ($self) = @_;

	my $vr = new Haiku::VolumeRoster;
	while (my $vol = $vr->GetNextVolume) {
		next unless $vol->KnowsQuery;
		my $query = new Haiku::Query;
#		push @{ $self->{queries} }, $query;
		
		$query->SetVolume($vol);
		$query->SetTarget(Haiku::Application::be_app_messenger);
#		$query->SetPredicate('(name=*) && (BEOS:TYPE=application/x-person)');
#		this is much faster than the above - why? is name or BEOS:TYPE not indexed?
		$query->SetPredicate('META:name=="*"');
		$query->Fetch;
		while (my $entry = $query->GetNextEntry) {
			$self->add_person($entry->GetPath->Path);
		}
		if ($Haiku::StorageKit::Error == Haiku::Errors::B_BAD_VALUE) {
			warn "Predicate includes unindexed attributes";
		}
		if ($Haiku::StorageKit::Error == Haiku::Errors::B_FILE_ERROR) {
			warn "Query hasn't fetched";
		}
	}
}

sub add_person {
	my ($self, $file) = @_;
	$self->{listwindow}->add_person($file);
}

sub remove_person {
	my ($self, $file) = @_;
	$self->{listwindow}->remove_person($file);
}

sub MessageReceived {
	my ($self, $msg) = @_;
	
	my $what = $msg->what;
	
	# why am I not getting these?
	if ($what == B_ENTRY_CREATED) {
print "Got an entry created message\n";
	}
	if ($what == B_ENTRY_REMOVED) {
print "Got an entry removed message\n";
	}
	
	$self->SUPER::MessageReceived($msg);
}

# need to know if a file was moved, renamed, etc.

1;

# need a list window
# need a person window
