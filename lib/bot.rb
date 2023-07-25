# frozen_string_literal: true
# Discord bot class
class ::DiscordBot::Bot

  @@DiscordBot = nil

  def self.init
    @@DiscordBot = Discordrb::Commands::CommandBot.new token: SiteSetting.discord_bot_token, prefix: '!'

    admin_channel_id =  SiteSetting.discord_bot_admin_channel_id
    @@DiscordBot.ready do |event|
      puts "Logged in as #{@@DiscordBot.profile.username} (ID:#{@@DiscordBot.profile.id}) | #{@@DiscordBot.servers.size} servers"
      @@DiscordBot.send_message(admin_channel_id, "The Discourse admin bot has started his shift!")
    end

    @@DiscordBot
  end

  def self.discord_bot
    @@DiscordBot
  end

  def self.run_bot
    bot = self.init

    unless bot.nil?
      ::DiscordBot::DiscourseEventsHandlers.hook_events
      bot.include!(::DiscordBot::DiscordEventsHandlers::TransmitAnnouncement)
      ::DiscordBot::BotCommands.manage_discord_commands(bot)
    end
  end
end
