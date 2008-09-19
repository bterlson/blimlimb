require 'rubygems'
require 'net/yail'

HOST = 'irc.freenode.net'
CHAN = '#bterlsontest'

class BotPlayer
  attr_reader :nick, :irc
  
  def initialize(nick)
    @irc = Net::YAIL.new(
      :address    => 'irc.freenode.net',
      :username   => nick,
      :realname   => nick,
      :nicknames  => [nick]
    )
    @done = false
    @irc.prepend_handler :incoming_welcome, method(:do_connected)
    @irc.start_listening
    @nick = nick
    
    while !@done && !@irc.dead_socket do
      # get the connection going!
      sleep 0.05
    end
  end
  
  def say(message)
    @irc.msg(CHAN, message)
  end
  
  def action(message)
    @irc.act(CHAN, message)
  end
  
  def renick(name)
    @nick = name
    @irc.nick(@nick)
  end
  
  def part(message)
    @irc.part(CHAN, message)
  end
  
  def quit(message)
    @irc.quit(message)
  end
  
  def join()
    @irc.join(CHAN)
  end
  
  private
  
  def do_connected(*args)
    @done = true
  end
end

class BotTroupe
  def initialize(script)
    @script = script
    @actors = {}
  end
  def parse line
      case line.strip
      when /^\[(\w+)\]\s+(.+?)$/
        kid, actor = $1, $2
        @actors[kid] = BotPlayer.new(actor)
        puts "Connect #{actor}"
      when /^\+(\w+)/
        kid = $1
        @actors[kid].join()
        puts "Part #{@actors[kid].nick}"
      when /^(\w+)=\s*(.+?)$/
        kid, nick = $1, $2
        puts "#{@actors[kid].nick} is now named #{nick}"
        @actors[kid].renick(nick)
      when /^(\w+):\s?(.+?)$/
        kid, msg = $1, $2
        @actors[kid].say(msg)
        puts "<#{@actors[kid].nick}> #{msg}"
      when /^\((\w+)\)\s+(.+?)$/
        kid, msg = $1, $2
        @actors[kid].action(msg)
        puts "** #{@actors[kid].nick} #{msg}"
      when /^\+\s*(\d+)/
        puts "Wait #{$1} secs"
        sleep $1.to_i
      when /^\*\s+(.+?)$/
        puts "--- okay, _why: your console - #$1 ---"
        while true
          puppet = $stdin.gets.strip
          break if puppet =~ /^\*/
          parse puppet
        end
      when /^\-(\w+)\s+(.+?)$/
        kid, msg = $1, $2
        @actors[kid].part(msg)
        puts "Exit #{@actors[kid].nick}"
      end
  rescue => e
      p e.message
  end
  def act!
    IO.foreach(@script) do |line|
      parse line
      sleep(1 + rand(8))
    end
  end
end
 
if __FILE__ == $0
  troupe = BotTroupe.new ARGV[0]
  troupe.act!
end