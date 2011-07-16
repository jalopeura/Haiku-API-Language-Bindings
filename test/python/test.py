import inspect
def dump(object):
	for item in inspect.getmembers(object):
		print "ITEM:", item,"\n\n"

import Haiku
#dump(Haiku)

class MyApplication(Haiku.CustomApplication):
	def __init__(self, *args):
		Haiku.CustomApplication.__init__(self, *args)
		self.window = MyWindow(
			Haiku.Rect(50,50,170,170),
			"Test Window",
			Haiku.WindowConstants.B_TITLED_WINDOW,
			Haiku.WindowConstants.B_QUIT_ON_WINDOW_CLOSE
			)
		self.window.Show()
	def ArgvReceived(self, args):
		print "ArgvReceived: ", args, "\n"
		return Haiku.Application.ArgvReceived(self, args)
	def AppActivated(self, active):
		print "AppActivated: ", active, "\n"
		return Haiku.Application.AppActivated(self, active)
	def QuitRequested(self):
		print "QuitRequested\n"
		return Haiku.Application.QuitRequested(self)
	def ReadyToRun(self):
		print "ReadyToRun\n"
		return Haiku.Application.ReadyToRun(self)
	def MessageReceived(self, message):
		print "MessageReceived: ", message, "\n"
		return Haiku.Application.MessageReceived(self, message)

class MyWindow(Haiku.CustomWindow):
	click_count = 0
	message_count = 0
	def __init__(self, *args):
		Haiku.CustomWindow.__init__(self, *args)
		self.button = Haiku.Button(
			Haiku.Rect(10,10,110,110),
			"Test Button",
			"Click Me",
			Haiku.Message(0x12345678),
			Haiku.ViewConstants.B_FOLLOW_LEFT | Haiku.ViewConstants.B_FOLLOW_TOP,	# resizingMode
			Haiku.ViewConstants.B_WILL_DRAW | Haiku.ViewConstants.B_NAVIGABLE	# flags
			)
		self.AddChild(self.button, 0)
	def MessageReceived(self, message):
		self.message_count += 1
		if (message.what == 0x12345678):
			self.click_count += 1
			self.button.SetLabel("%d of %d" % (self.click_count, self.message_count));
			return
		return Haiku.Window.MessageReceived(self, message)

#dump(MyApplication)

TestApp = MyApplication("application/python-binding-test")

TestApp.Run()
