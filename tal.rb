#!/usr/bin/env ruby
require 'rubygems'
require 'cgi'
require 'cinch'
require 'nokogiri'
require 'open-uri'
require 'yaml'
require 'pry'

begin
  $yaml = YAML.load_file('/etc/tal.yaml')
rescue 
  $stderr.print "Error: Could not find file /etc/tal.yaml\n"
  exit 1
end

$hi_string = /(#{$yaml['hi'].join('|')})/i
$bye_string = /(#{$yaml['bye'].join('|')})/i
$users = []
$history = {}

class Seen < Struct.new(:who, :where, :what, :time)
  def to_s
    "[#{time.asctime}] #{who} was seen last in #{where} saying \"#{what}\"."
  end
end

class Tal
  include Cinch::Plugin
  listen_to :channel

  def initialize(*args)
    super
    @seen = {}
  end

  def urban_dict(query)
    url = "http://www.urbandictionary.com/define.php?term=#{CGI.escape(query)}"
    CGI.unescape_html Nokogiri::HTML(open(url)).at("div.meaning").text.gsub(/\s+/, ' ') rescue nil
  end

  def pick_reply(a)
    i = a[rand(a.length-1)].gsub(/[\?\\]/, '')
    if a == $users
      i
    else
      i.capitalize
    end 
  end

  set :prefix, //

  match /\b[Tt]al,? where is ([a-zA-Z0-9\-_]+)\b/, method: :seen, use_prefix: false
  match /\b[Tt]al,?\b/, use_prefix: false

  def seen(m, nick)
    if nick == @bot.nick
      m.reply "That's me!"
    elsif nick == m.user.nick
      m.reply "That's you!"
    elsif @seen.key?(nick)
      m.reply @seen[nick].to_s
    else
      m.reply "I haven't seen #{nick}"
    end
  end

  def listen(m)
    @seen[m.user.nick] = Seen.new(m.user, m.channel, m.message, Time.now)
    regexyou = /(\w+): s\/(.+)\/(.+)\//i.match(m.message)
    regexme = /s\/(.+)\/(.+)\//i.match(m.message)
    if regexyou
      new = Format( :italic, $history[regexyou[1]].gsub(/#{regexyou[2]}/i, regexyou[3]) )
      unless m.user.nick == regexyou[1]
        Channel($yaml['connect']['channels'].first).send "#{m.user.nick} thinks #{regexyou[1]} meant \"#{new}\""
      else
        Channel($yaml['connect']['channels'].first).send "#{m.user.nick} meant \"#{new}\""
      end
    elsif regexme
      new = Format( :italic, $history[m.user.nick].gsub(/#{regexme[1]}/i, regexme[2]) )
      Channel($yaml['connect']['channels'].first).send "#{m.user.nick} meant \"#{new}\""
      $history[m.user.nick] = new
    elsif m.message =~ /\b(#{$yaml['curse'].join('|')})\b/i
      Channel($yaml['connect']['channels'].first).send "That's not necessary, #{m.user.nick}."
    end
  end

  def execute(m)
    case m.message
    when /\b(#{$yaml['curse'].join('|')})\b/i
      m.reply "That's not necessary, #{m.user.nick}."
    when $hi_string
      reply = pick_reply($yaml['hi'])
      m.reply "#{reply}, #{m.user.nick}!"
    when $bye_string
      reply = pick_reply($yaml['bye'])
      m.reply "#{reply}, #{m.user.nick}!"
    when /how are you/
      reply = pick_reply($yaml['howareyou'])
      m.reply "I'm #{reply}, #{m.user.nick}!"
    when /good morning/i
      m.reply "Good morning, #{m.user.nick}."
    when /shut up/i
      timers.first.interval=timers.first.interval+120
      m.reply "I'm sorry, #{m.user.nick}."
    when /no thanks?( you)?/i
      m.reply "No problem, #{m.user.nick}."
    when /thanks?( you)?/i
      m.reply "You're welcome, #{m.user.nick}."
    when /(what'?s the time|what time is it)/
      time = Time.new
      m.reply "The current time is #{time.inspect}."
    when /where is/i
    when /define|(what is)/i
      term = /(?:(?:define)|(?:what is\s?a?n?)) (.*)\b/i.match(m.message)[1]
      m.reply(urban_dict(term) || "No results found", true)
    else
      m.reply "#{m.user.nick}, I don't understand."
    end
  end

  $intal = rand(300...900)
  timer rand($intal), method: :timed
  def timed
    begin
      target = self.pick_reply($users)
      #Channel($yaml['connect']['channels'].first).send "[#{intal}] #{self.pick_reply($yaml['talhate'])}, #{target}!"
      $users = []
    rescue
      $intal
    else
      timers.first.interval = rand($intal)
    end
  end

end

bot = Cinch::Bot.new do
  configure do |c|
    y                 = $yaml['connect']
    c.server          = y['server']
    c.port            = y['port']
    c.modes           = y['modes']    if y['modes']
    c.password        = y['password'] if y['password']
    c.channels        = y['channels'] if y['channels']
    c.nick            = 'Tal'
    c.user            = 'Tal'
    c.plugins.plugins = [Tal]
  end
  
  on :channel do |m|
    $users << m.user.nick
    debug "Target array: #{$users}"
    $history[m.user.nick] = m.message if m.message !~ /(\w+: )?s\/.+\/.+\//i
    debug "History hash: #{$history}"
  end

end

bot.start
