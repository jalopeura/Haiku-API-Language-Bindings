import Haiku
from Haiku.WindowConstants import \
	B_TITLED_WINDOW, \
	B_QUIT_ON_WINDOW_CLOSE
from Haiku.ViewConstants import \
	B_FOLLOW_LEFT, \
	B_FOLLOW_TOP, \
	B_WILL_DRAW, \
	B_NAVIGABLE

message = Haiku.Message(0)

app = Haiku.Application("application/python-test")
window = Haiku.Window(
	Haiku.Rect(50,50,170,170),
	"Test Window",
	B_TITLED_WINDOW,
	B_QUIT_ON_WINDOW_CLOSE
	)
button = Haiku.Button(
	Haiku.Rect(10,10,110,110),
	"Test Button",
	"Click Me",
	message,
	B_FOLLOW_LEFT | B_FOLLOW_TOP,
	B_WILL_DRAW | B_NAVIGABLE
	)
window.AddChild(button, 0)

child = window.ChildAt(0)
print "Should get a wrapper object; got", child

child = window.ChildAt(1)
print "Should get nothing (instead of an empty wrapper); got", child

item = Haiku.MenuItem(
	"Test",
	Haiku.Message(0),
	30,
	10
	)

char, mod = item.Shortcut()
print "Should get two return values; got", char, "and", mod
