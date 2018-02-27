
local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local sync = require'websocket.sync'
local tconcat = table.concat
local tinsert = table.insert

local clients = {}

local client = function(sock,protocol)
  local loop = require'socketloop'

  local self = {}

  local asock = loop.wrap(sock)

  self.state = 'OPEN'
  self.is_server = true

  self.sock_send = function(self,...)
    return asock:send(...)
  end

  self.sock_receive = function(self,...)
    return asock:receive(...)
  end

  self.sock_close = function(self)
    asock:shutdown()
    asock:close()
  end

  self = sync.extend(self)

  self.on_close = function(self)
    clients[protocol][self] = nil
  end

  self.broadcast = function(self,...)
    for client in pairs(clients[protocol]) do
      if client ~= self then
        client:send(...)
      end
    end
    self:send(...)
  end

  return self
end

local listen = function(opts)
  local loop = require'socketloop'
  assert(opts and (opts.protocols or opts.default))
  local on_error = opts.on_error or function(s) print(s) end

  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols,protocol)
    end
  end

  -- true is the 'magic' index for the default handler
  clients[true] = {}

  local listener = loop.newserver(
    opts.interface or '*',
    opts.port or 80,
    function(sock)
      local request = {}
      repeat
        -- no timeout used, so should either return with line or err
        local line,err = sock:receive('*l')
        if line then
          request[#request+1] = line
        else
          sock:close()
          if on_error then
            on_error('invalid request')
          end
          return
        end
      until line == ''
      local upgrade_request = tconcat(request, '\r\n')
      local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
      if not response then
        sock:send(protocol)
        sock:close()
        if on_error then
          on_error('invalid request')
        end
        return
      end
      sock:send(response)
      local handler
      local new_client
      local protocol_index
      if protocol and opts.protocols[protocol] then
        protocol_index = protocol
        handler = opts.protocols[protocol]
      elseif opts.default then
        -- true is the 'magic' index for the default handler
        protocol_index = true
        handler = opts.default
      else
        sock:close()
        if on_error then
          on_error('bad protocol')
        end
        return
      end
      new_client = client(sock,protocol_index)
      clients[protocol_index][new_client] = true
      handler(new_client)
      -- ...ignoring the copas 'dirty trick', hoping it's not needed for socketloop...
    end
  )

  local self = {}
  self.close = function(_,keep_clients)
    listener:close()
    listener = nil
    if not keep_clients then
      for protocol,clients in pairs(clients) do
        for client in pairs(clients) do
          client:close()
        end
      end
    end
  end

  return self
end

return {
  listen = listen
}
