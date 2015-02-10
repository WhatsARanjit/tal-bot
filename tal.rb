#!/usr/bin/env ruby
require 'rubygems'
require 'cinch'

bot = Cinch::Bot.new do
  configure do |c|
    c.server   = 'irc.whatsaranjit.com'
    c.port     = '7666'
    c.password = 'Conversion11'
    c.channels = ['#Impternal']
  end

  on :message, "hello" do |m|
    m.reply "Hello, #{m.user.nick}"
  end
end

bot.start
