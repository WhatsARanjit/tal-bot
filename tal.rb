#!/usr/bin/env ruby
require 'rubygems'
require 'cgi'
require 'cinch'
require 'nokogiri'
require 'open-uri'
require 'yaml'
require 'pry'

begin
  yaml = YAML.load_file('/etc/tal.yaml')
rescue 
  $stderr.print "Error: Could not find file /etc/tal.yaml\n"
  exit 1
end

$hi_string = /(#{yaml['hi'].join('|')})/i
$bye_string = /(#{yaml['bye'].join('|')})/i

class Tal
  include Cinch::Plugin

  def urban_dict(query)
    url = "http://www.urbandictionary.com/define.php?term=#{CGI.escape(query)}"
    CGI.unescape_html Nokogiri::HTML(open(url)).at("div.meaning").text.gsub(/\s+/, ' ') rescue nil
  end

  set :prefix, //
  match /\b[Tt]al,?\b/

  def execute(m)
    case m.message
    when $hi_string
      m.reply "Hello, #{m.user.nick}!"
    when $bye_string
      m.reply "Bye, #{m.user.nick}!"
    when /no thanks?( you)?/i
      m.reply "No problem, #{m.user.nick}."
    when /thanks?( you)?/i
      m.reply "You're welcome, #{m.user.nick}."
    when /(what'?s the time|what time is it)/
      time = Time.new
      m.reply "The current time is #{time.inspect}."
    when /define|(what is)/i
      term = /(?:define)|(?:what is\s?a?n?) (.*)\b/i.match(m.message)[1]
      m.reply(urban_dict(term) || "No results found", true)
    else
      m.reply "#{m.user.nick}, I don't understand."
    end
  end


end

bot = Cinch::Bot.new do
  configure do |c|
    y                 = yaml['connect']
    c.server          = y['server']
    c.port            = y['port']
    c.modes           = y['modes']    if y['modes']
    c.password        = y['password'] if y['password']
    c.channels        = y['channels'] if y['channels']
    c.nick            = 'Tal'
    c.user            = 'Tal'
    c.plugins.plugins = [Tal]
  end

end

bot.start
