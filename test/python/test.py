import inspect
import Haiku	# prevents a name not defined error
import Haiku.ApplicationKit
import Haiku.InterfaceKit
#for item in inspect.getmembers(Haiku):
#	print "ITEM:", item,"\n\n"

#Haiku.Application.CustomApplication.__bases__ = Haiku.Application.Application
#Haiku.Window.CustomWindow.__bases__ = Haiku.Window.Window

class MyApplication(Haiku.Application.CustomApplication):
	def ArgvReceived(self, args):
		print "ArgvReceived: ", args, "\n"
		return Haiku.Application.Application.ArgvRecieved(self, args)
	def AppActivated(self, active):
		print "AppActivated: ", active, "\n"
		return Haiku.Application.Application.AppActivated(self, active)
	def QuitRequested(self):
		print "QuitRequested\n"
		return Haiku.Application.Application.QuitRequested(self)
	def ReadyToRun(self):
		print "ReadyToRun\n"
		return Haiku.Application.Application.ReadyToRun(self)
	def MessageReceived(self, message):
		print "MessageReceived: ", message, "\n"
		return Haiku.Application.Application.MessageReceived(self, message)

class MyWindow(Haiku.Window.CustomWindow):
	click_count = 0
	message_count = 0
	def MessageReceived(self, message):
		message_count += 1
		if (message.what == 0x12345678):
			click_count ++ 1
			main.TestButton.SetLabel("click_count of message_count")
			return
		return Haiku.Application.Application.MessageReceived(self, message)

#for item in inspect.getmembers(Haiku.Window.CustomWindow):
#	print "ITEM:", item,"\n\n"

#print MyWindow.__bases__
#print Haiku.Window.CustomWindow.__bases__

#print MyWindow.__mro__
#print Haiku.Window.CustomWindow.__mro__

TestApp = MyApplication("application/python-binding-test")

TestWindow = MyWindow(
	Haiku.Rect.Rect(50,50,250,250),
	"Test Window",
	Haiku.InterfaceKit.B_TITLED_WINDOW,
	Haiku.InterfaceKit.B_QUIT_ON_WINDOW_CLOSE
	)

TestButton = Haiku.Button.Button(
	Haiku.Rect.Rect(10,10,110,110),
	"Test Button",
	"Click Me",
	Haiku.Message.Message(0x12345678),
	Haiku.InterfaceKit.B_FOLLOW_LEFT | Haiku.InterfaceKit.B_FOLLOW_TOP,	# resizingMode
	Haiku.InterfaceKit.B_WILL_DRAW | Haiku.InterfaceKit.B_NAVIGABLE	# flags
	)

TestWindow.AddChild(TestButton, 0)

TestWindow.Show()

TestApp.Run()
