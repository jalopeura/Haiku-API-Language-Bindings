# for testing before installation
BEGIN {
	my $folder = '../../generated/perl/';
	for my $kit (qw(HaikuKits)) {
		push @INC, "$folder$kit/blib/lib";
		push @INC, "$folder$kit/blib/arch";
	}
}

use Haiku::SupportKit;
use Haiku::ApplicationKit;
use Haiku::InterfaceKit;
use Test::Simple tests =>  6;

$Haiku::ApplicationKit::DEBUG = 4;
$Haiku::InterfaceKit::DEBUG = 4;

ok(1, 'Modules loaded');

my $message = new Haiku::Message(0);

my $status = $message->AddInt8('x', 1);
ok($status, "Return true [$status] true on success");

my $status = $message->AddBool('x', 1);	# can't add different types under same name
ok(!defined($status), "Return undef [$status] on error (error var set to $Haiku::ApplicationKit::Error / $!)");

my $app = new Haiku::Application("application/perl-test");
my $window = new Haiku::Window(
	new Haiku::Rect(50,50,170,170),	# frame
	"Test Window",	# title
	B_TITLED_WINDOW,	# type
	B_QUIT_ON_WINDOW_CLOSE,	# flags
);
my $button = new Haiku::Button(
	new Haiku::Rect(10,10,110,110),	# frame
	"TestButton",	# name
	"Click Me",	# label
	$message,	# message
	B_FOLLOW_LEFT | B_FOLLOW_TOP,	# resizingMode
	B_WILL_DRAW | B_NAVIGABLE,	# flags
);
$window->AddChild($button, 0);
my $child = $window->ChildAt(0);
ok($child, "Return perl wrapper [$child] for object");
$child = $window->ChildAt(1);
ok(!defined($child), "Return undef [$child] for NULL object (instead of empty perl object)");

my $item = new Haiku::MenuItem(
	'test',
	new Haiku::Message(0),
	30,
	10,
);
my ($char, $mod) = $item->Shortcut;
ok($char && $mod, "Multiple return values: [$char] [$mod]");
