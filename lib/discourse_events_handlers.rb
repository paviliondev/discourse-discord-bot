# frozen_string_literal: true
module ::DiscordBot::DiscourseEventsHandlers
  def self.hook_events
    DiscourseEvent.on(:post_created) do |post|
      if post.id > 0 && post.topic.archetype != 'private_message' && !::DiscordBot::Bot.discord_bot.nil? then
        post_listening_categories = SiteSetting.discord_bot_post_announcement_categories.split('|')
        topic_listening_categories = SiteSetting.discord_bot_topic_announcement_categories.split('|')
        posted_category = post.topic.category.id
        posted_category_name = Category.find_by(id: posted_category).name
        if post_listening_categories.include?(posted_category.to_s) then
          message = I18n.t("discord_bot.discourse_events.announce_new_post", posted_category_name: posted_category_name, url: Discourse.base_url + post.base_url)
          ::DiscordBot::Bot.discord_bot.send_message(SiteSetting.discord_bot_announcement_channel_id, message)
        else
          if topic_listening_categories.include?(posted_category.to_s) && post.post_number = 1 then
            message = I18n.t("discord_bot.discourse_events.announce_new_topic", posted_category_name: posted_category_name, url: Discourse.base_url + post.base_url)
            ::DiscordBot::Bot.discord_bot.send_message(SiteSetting.discord_bot_announcement_channel_id, message)
          end
        end
      end
    end
  end
end
