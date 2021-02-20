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
    end
  end
end
