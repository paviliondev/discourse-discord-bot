module ::DiscordBot::DiscordEventsHandlers
  # Copy message to Discourse
  module TransmitAnnouncement
    extend Discordrb::EventContainer
    message do |event|
      # Copy the message to the assigned Discourse announcement Topic if assigned in plugin settings
      discourse_announcement_topic = Topic.find_by(id: SiteSetting.discord_bot_discourse_announcement_topic_id)
      unless discourse_announcement_topic.nil?
        system_user = User.find_by(id: -1)
        raw = event.message.to_s
        new_post = PostCreator.new(system_user, raw: raw, topic_id: discourse_announcement_topic.id)
        new_post.create!
      end
      if SiteSetting.discord_bot_auto_channel_sync
        matching_category = Category.find_by(name: event.message.channel.name)
        unless matching_category.nil?
          raw = event.message.to_s
          system_user = User.find_by(id: -1)
          if !(target_topic = Topic.find_by(title: I18n.t("discord_bot.discord_events.auto_message_copy.default_topic_title", channel_name: matching_category.name))).nil?
            new_post = PostCreator.create!(system_user, raw: raw, topic_id: target_topic.id, skip_validations: true)
          else
            new_post = PostCreator.create!(system_user, title: I18n.t("discord_bot.discord_events.auto_message_copy.default_topic_title", channel_name: matching_category.name), raw: raw, category: matching_category.id, skip_validations: true)
          end
        end
      end
    end
  end
end
