import inspect
def dump(object):
	for item in inspect.getmembers(object):
		print "ITEM:", item,"\n\n"

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
	"a",
	10
	)

char, mod = item.Shortcut()
print "Should get two return values; got", char, "and", mod

origin = Haiku.PointConstants.B_ORIGIN
print "Should get a non-integer constant; got", origin

be_app = Haiku.Application.be_app()
print "Should get a global; got", be_app

pattern = Haiku.pattern();
data = pattern.data
print "Should get an array; got", data

data[2] = 0x10
pattern.data = data
print "Should get changed value; got", pattern.data

menu_info = Haiku.menu_info()
menu_info.f_family = "Test String"
print "Should get 'Test String'; got", menu_info.f_family

print "Should get methods from different base classes; got", \
	button.Window, "and", button.Message

print "app and be_app comparison:", (app == be_app)

x = 10
y = 10
point = Haiku.Point(x,y)
#negpoint = -point
negpoint = Haiku.Point(-x,-y)
print "Should get negated values:", point.x, point.y, "vs", negpoint.x, negpoint.y

#
# This causes a memory problem when exiting
#
opoint = point + negpoint
print "Should get a true value:", opoint == Haiku.PointConstants.B_ORIGIN
print "Should get all zeros: got:", opoint.x, opoint.y

point += point;
print "Should get doubled values; got", point.x, point.y

color = Haiku.rgb_color()
color.red = 10
color.green = 20
color.blue = 30

text_run = Haiku.text_run()
text_run.offset = 0
text_run.color = color

text_run_array = Haiku.text_run_array()
text_run_array.runs = [ text_run ]
tra = text_run_array.runs

menu_info = Haiku.menu_info()
menu_info.f_family = "Test"
fam = menu_info.f_family

view = Haiku.View(
	Haiku.Rect(0,0,0,0),
	"Test",
	0,
	0
	)
view.DrawStringWithLength("Test")
print "Got here"
