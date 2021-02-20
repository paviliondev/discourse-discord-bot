module ::DiscordBot::DiscordEventsHandlers
  # Copy message to Discourse
  module TransmitAnnouncement
    extend Discordrb::EventContainer
    message do |event|
      # Copy the message to the assigned Discourse announcement Topic if assigned in plugin settings
      discourse_announcement_topic = Topic.find_by(id: SiteSetting.discord_bot_discourse_announcement_topic_id)
      unless discourse_announcement_topic.nil?
        new_post = Post.new
        new_post.user_id = -1
        new_post.topic_id = discourse_announcement_topic.id
        new_post.raw = event.message
        new_post.save
      end
    end
  end
end
