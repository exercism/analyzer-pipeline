require 'rubygems'
require 'ffi-rzmq'

context = ZMQ::Context.new 2

req = context.socket(ZMQ::REQ)
puts req.bind('ipc://routing.ipc')

sleep 2

Thread.new do
  socket = context.socket(ZMQ::ROUTER)
  puts socket.setsockopt(ZMQ::IDENTITY, "foobar")
  puts socket.connect('ipc://routing.ipc')

  sleep 2

  loop do
    puts "waiting"
    socket.recv_string(message = '')
    puts "Received [#{message}]"
    socket.send_string("OK " + message)
  end

end

10.times do |request|
  ss = "Hello #{request}"
  puts req.setsockopt(ZMQ::IDENTITY, "baz")
  req.send_string("foobar", ZMQ::SNDMORE)
  req.send_string("foobar", ZMQ::SNDMORE)
  req.send_string("foobar", ZMQ::SNDMORE)
  req.send_string("foobar", ZMQ::SNDMORE)
  req.send_string("", ZMQ::SNDMORE)
  req.send_string(ss)
  puts "Sending string [#{ss}]"
  req.recv_string(message = '')
  puts "Received reply #{request}[#{message}]"
end
