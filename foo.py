import time
print("Running python file")
def throw():
    time.sleep(10)
    raise Exception("Exception from python")

def bar():
    throw()

def foo():
    bar()

foo()
