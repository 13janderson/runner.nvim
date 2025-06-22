--- @class Handler
local Handler = {}

-- Need a layer above this, some kind of handler which we call out to to handle 
-- setting the quickfix list from stderr_buffered.
-- First need a way of expresing this as a class, then need a way of registering 
-- a class as the handler for some run.

--- @param stderr string[]
function Handler:handle(_)
  print("handling")
end

function Handler:where()
end

return Handler
