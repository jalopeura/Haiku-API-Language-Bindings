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

#print message.what
#message.what = 0xff
#print message.what

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

origin = Haiku.PointConstants.B_ORIGIN
print "Should get a non-integer constant; got", origin

global_be_app = Haiku.Application.be_app()
print "Should get a global; got", global_be_app

pattern = Haiku.pattern();
data = pattern.data
print "Should get an array; got", data

data[2] = 0x10
pattern.data = data
print "Should get changed value; got", pattern.data

# test multiple inheritance (when something multiple inherited is defined)
