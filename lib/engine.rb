module ::DiscordBot
  class Engine < ::Rails::Engine
    engine_name "discord_bot"
    isolate_namespace DiscordBot
  end
end