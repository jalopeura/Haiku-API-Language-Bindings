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

use Haiku::Window qw(B_TITLED_WINDOW B_QUIT_ON_WINDOW_CLOSE);
use Haiku::View qw(B_FOLLOW_LEFT B_FOLLOW_TOP B_WILL_DRAW B_NAVIGABLE);

use Test::Simple tests =>  18;
use strict;

$Haiku::ApplicationKit::DEBUG = 0;
$Haiku::InterfaceKit::DEBUG = 0;
$Haiku::StorageKit::DEBUG = 0;
$Haiku::SupportKit::DEBUG = 0;

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
	'a',
	10,
);
my ($char, $mod) = $item->Shortcut;
ok($char && $mod, "Multiple return values working: [$char] [$mod]");

my $origin = Haiku::Point::B_ORIGIN;
ok(ref($origin), "Non-integer constants working [$origin]");

my $err = Haiku::Errors::B_OS_ERROR_BASE; my $num_err = $err+0;
ok(($err eq 'B_OS_ERROR_BASE'), "Dual value constants working: $err, $num_err");

my $be_app = Haiku::Application::be_app;
ok(ref($be_app), "Globals working [$be_app]");

my $pattern = new Haiku::pattern;
my $aref = $pattern->data;
ok(ref($aref) eq 'ARRAY', sprintf("Return aref [$aref => %s] for an array property", join(' ', @$aref)));

$aref->[2] = 0x10;
$pattern->data = $aref;
$aref = $pattern->data;
ok($pattern->data->[2] == 0x10, sprintf("Set an element of an array property: %s", join(' ', @{ $pattern->data })));

binmode(STDOUT, ':utf8');
my $test_string = join('', map { chr $_ } 0x100..0x109);
my $menu_info = new Haiku::menu_info;
$menu_info->f_family = $test_string;
#my $ret_string = unpack('Z64', $menu_info->f_family);
my $ret_string = $menu_info->f_family;
ok($test_string eq $ret_string, "Set and return char strings [$test_string <=> $ret_string]");

=pod

ok(length($menu_item->f_family) == 64, '');
$family=~s/([\0-\x1a\x7f])/sprintf("\\x{%X}", ord $1)/ge;
print $family,"\n";

$menu_item->f_family = 
$family = $menu_item->f_family;
$family=~s/([\0-\x1a\x7f])/sprintf("\\x{%X}", ord $1)/ge;
print $family,"\n";

=cut

ok(($button->Window and $button->Message), "Multiple inheritance");

ok($app == $be_app, "Default equality operator");

my $x = 10; my $y = 10;
my $point = new Haiku::Point($x,$y);
my $negpoint = -$point;
ok(($point->x == -1 * $negpoint->x and $point->y == -1 * $negpoint->y), "Negation operator");

my $opoint = $point + $negpoint;
ok($opoint == Haiku::Point::B_ORIGIN, "Comparison operator");
ok(($opoint->x == 0 and $opoint->y == 0), "Mathematical operator");

$point += $point;
ok(($point->x == 2 * $x and $point->y == 2 * $y), "Mutator operator");

my $color = new Haiku::rgb_color;
$color->red = 10;
$color->green = 20;
$color->blue = 30;
print $color,"\n";

my $text_run = new Haiku::text_run;
$text_run->offset = 0;
$text_run->color = $color;
print $text_run,"\n";

my $text_run_array = new Haiku::text_run_array;
print $text_run_array,"\n";
$text_run_array->runs = [ $text_run ];
print "Set it\n";
my $tra = $text_run_array->runs;
print "Got it\n";
print $text_run_array,"\n";

my $menu_info = new Haiku::menu_info;
$menu_info->f_family = "Test";
my $fam = $menu_info->f_family;

$button->DrawStringWithLength("Test");
