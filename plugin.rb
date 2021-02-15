# name: discord bot
# about: Integrate Discord Bots with Discourse
# version: 0.1
# authors: Robert Barrow
# url: https://github.com/merefield/discourse-discord-bot

gem 'rbnacl', '3.4.0'
gem 'event_emitter', '0.2.6'
gem 'websocket', '1.2.8'
gem 'websocket-client-simple', '0.3.0'
gem 'opus-ruby', '1.0.1', { require: false }
gem 'netrc', '0.11.0'
gem 'mime-types-data', '3.2019.1009'
gem 'mime-types', '3.3.1'
gem 'domain_name', '0.5.20180417'
gem 'http-cookie','1.0.3'
gem 'http-accept', '1.7.0', { require: false }
gem 'rest-client', '2.1.0.rc1'

gem 'discordrb-webhooks', '3.3.0', {require: false}
gem 'discordrb', '3.3.0'

require 'discordrb'

enabled_site_setting :discord_bot_enabled

register_asset 'stylesheets/common/discord.scss'

after_initialize do

  %w[
    ../lib/bot.rb
    ../lib/bot_commands.rb
  ].each do |path|
    load File.expand_path(path, __FILE__)
  end

  bot_thread = Thread.new do
    begin
      DiscordBot.run_bot
    rescue Exception => ex
      Rails.logger.error("Discord Bot: There was a problem: #{ex}")
    end
  end

  STDERR.puts '---------------------------------------------------'
  STDERR.puts 'Bot should now be spawned, say "Ping!" on Discord!'
  STDERR.puts '---------------------------------------------------'
  STDERR.puts '(-------      If not check logs          ---------)'
end
