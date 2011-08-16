#!perl
# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

use People::Application;
use Haiku::SupportKit;
use Haiku::ApplicationKit;
use Haiku::InterfaceKit;
use Haiku::StorageKit;
use strict;

#$SIG{__WARN__} = sub {
#	new Haiku::Alert(
#		"Warning",	# title
#		$_[0],	# text
#		'Ok',	# button 1 label
#	)->Go;
#};

$Haiku::ApplicationKit::DEBUG = 0;
$Haiku::InterfaceKit::DEBUG = 0;
$Haiku::StorageKit::DEBUG = 0;
$Haiku::SupportKit::DEBUG = 0;

my $podviewer = new People::Application;

$podviewer->Run;

undef $SIG{__WARN__};
