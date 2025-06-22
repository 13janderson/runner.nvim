print("Running python file")
def throw():
    raise Exception("Exception from python")

def bar():
    throw()

def foo():
    bar()

foo()
