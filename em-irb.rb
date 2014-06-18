require 'irb'
require 'em-synchrony'

# we're faking IRB::StdioInputMethod instead of raw IRB::InputMethod, so we get a prompt
class EMInputMethod < IRB::StdioInputMethod
  def initialize(sock)
    super()
    @line_no = 0
    @line = []
    @io = sock
  end

  def gets
    @io.write @prompt
    d = @io.recv(4096)
    return d if d.nil?
    line, rest = d.split("\n", 2)
    if rest.nil?
      @io.instance_eval{ @in_buff = line }
    else
      @io.instance_eval{ @in_buff = rest + @in_buff }
      line << "\n"
      @line[@line_no += 1] = line
    end
  end

  def eof?
    @io.closed?
  end

  def readable_after_eof?
    true
  end

  def line(line_no)
    @line[line_no]
  end

  def encoding
    Encoding.find('UTF-8')
  end
end

class EMOutputMethod < IRB::OutputMethod
  def initialize(sock)
    super()
    @io = sock
  end

  def print(*opts)
    opts.each{|opt| @io.write(opt.to_s) }
  rescue Errno::EPIPE
  end
end

# XXX: work around https://bugs.ruby-lang.org/issues/9876
class IRB::Context
  attr_accessor :output_method
end
class IRB::Irb
  def print *args
    @context.output_method.print *args
  end
  def printf *args
    @context.output_method.printf *args
  end
end

class WorkSpace

  def wrap
    old_stdout = $stdout
    my_stdout = StringIO.new
    $stdout = my_stdout
    begin
      return yield
    ensure
      $stdout = old_stdout
      @io.write my_stdout.string
    end
  end

  [:p, :pp, :print, :printf, :putc, :puts].each do |m|
    define_method(m) do |*args, &block|
      wrap do
        Kernel.send(m, *args, &block)
      end
    end
  end

  def initialize(sock)
    @io = sock
  end

  # for the prompt
  def to_s
    'main'
  end
  def inspect
    'main:Object'
  end
end

class EventMachine::Irb < EM::Synchrony::TCPSocket
  def post_init
    super
    f = Fiber.new {

      irb = IRB::Irb.new(IRB::WorkSpace.new(WorkSpace.new(self)), EMInputMethod.new(self), EMOutputMethod.new(self))

      IRB.conf[:IRB_RC].call(irb.context) if IRB.conf[:IRB_RC]
      IRB.conf[:MAIN_CONTEXT] = irb.context

      begin
        catch(:IRB_EXIT) do
          irb.eval_input
        end
      ensure
        close_connection
        # XXX: once, or each connection?
        IRB.irb_at_exit
      end

    }.resume
  end
end

IRB.setup(nil)

