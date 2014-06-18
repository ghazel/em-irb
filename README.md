em-irb
======

interactive remote IRB repl for EventMachine

### Usage

EventMachine::start_server '127.0.0.1', 1234, EM::Irb

Then you can telnet to it and it acts like irb. I recommend rlwrap, too:

    $ rlwrap telnet localhost 4102
    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    1.9.3-p286 :001 > p 'hello em-world'
    "hello em-world"
     => "hello em-world"
