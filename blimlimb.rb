require 'rbot/rfc2812'
require 'rbot/ircsocket'
require 'rbot/timer'
require 'rbot/message'

HOST = 'irc.freenode.net'
CHAN = '#stage'
FROM = 'blim.limb'

def debug(message=nil)
  print "DEBUG: #{message}\n" if message
end

class BotPlayer
  attr_reader :nick, :socket, :client
  def initialize(nick)
    @socket = Irc::IrcSocket.new(HOST, 6667, false)
    @client = Irc::IrcClient.new
    @nick = nick
    @client[:welcome] = proc do |data|
      @socket.queue "JOIN #{CHAN}"
    end
  end
  def connect
    @socket.connect
    @socket.puts "NICK #{@nick}\nUSER #{@nick} 4 #{FROM} :blimLimb, of #camping"
    @socket.puts "JOIN #{CHAN}"
    Thread.start(self) do |bot|
      while true
        while bot.socket.connected?
          if bot.socket.select
            break unless reply = bot.socket.gets
            bot.client.process reply
          end
        end
      end
    end
  end
  def msg(type, where, message)
    @socket.queue("#{type} #{where} :#{message}")
  end
  def say(message)
    msg("PRIVMSG", CHAN, message)
  end
  def action(message)
    msg("PRIVMSG", CHAN, "\001ACTION #{message}\001")
  end
  def renick(name)
    @nick = name
    @socket.queue("NICK #{@nick}")
  end
  def quit(message)
    @socket.puts "QUIT :#{message}"
    @socket.flush
    @socket.shutdown
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
        @actors[kid].connect
        puts "Join #{actor}"
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
        @actors[kid].quit(msg)
        puts "Exit #{@actors[kid].nick}"
      end
  rescue => e
      p e.message
  end
  def act!
    IO.foreach(@script) do |line|
      parse line
      sleep(1+ rand(8))
    end
  end
end

if __FILE__ == $0
  troupe = BotTroupe.new ARGV[0]
  troupe.act!
end
