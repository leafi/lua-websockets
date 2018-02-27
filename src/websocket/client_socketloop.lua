local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local new = function(ws)
  ws = ws or {}
  local loop = require'socketloop'

  local self = {}

  self.sock_connect = function(self,host,port)
    local skt = assert(socket.tcp())
    self.sock = loop.wrap(skt)
    if ws.timeout ~= nil then
      self.sock:settimeout(ws.timeout)
    end
    local _,err = self.sock:connect(host,port)
    if err and err ~= 'already connected' then
      self.sock:close()
      return nil,err
    end
  end

  self.sock_send = function(self,...)
    return self.sock:send(...)
  end

  self.sock_receive = function(self,...)
    return self.sock:receive(...)
  end

  self.sock_close = function(self)
    self.sock:shutdown()
    self.sock:close()
  end

  self = sync.extend(self)
  return self
end

return new
