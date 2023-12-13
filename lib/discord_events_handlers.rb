# frozen_string_literal: true
module ::DiscordBot::DiscordEventsHandlers
  # Copy message to Discourse
  module TransmitAnnouncement
    extend Discordrb::EventContainer
    message do |event|

      RailsMultisite::ConnectionManagement.each_connection do
        next if event.message.channel.id.to_s != SiteSetting.discord_bot_announcement_channel_id

        next if !SiteSetting.discord_bot_auto_channel_sync && SiteSetting.discord_bot_discourse_announcement_topic_id.blank

        system_user = User.find_by(id: -1)

        associated_user = UserAssociatedAccount.find_by(provider_uid: event.message.author.id, provider_name: 'discord')
        if associated_user.nil?
          posting_user = system_user
        else
          posting_user = User.find_by(id: associated_user.user_id)
        end

        raw = event.message.to_s
        if !raw.blank?
          if SiteSetting.discord_bot_auto_channel_sync
            matching_category = Category.find_by(name: event.message.channel.name)
            unless matching_category.nil?
              if !(target_topic = Topic.find_by(title: I18n.t("discord_bot.discord_events.auto_message_copy.default_topic_title", channel_name: matching_category.name))).nil?
                new_post = PostCreator.create!(posting_user, raw: raw, topic_id: target_topic.id, skip_validations: true)
              else
                new_post = PostCreator.create!(posting_user, title: I18n.t("discord_bot.discord_events.auto_message_copy.default_topic_title", channel_name: matching_category.name), raw: raw, category: matching_category.id, skip_validations: true)
              end
              return
            end
          end
          if !SiteSetting.discord_bot_discourse_announcement_topic_id.blank? && (event.message.channel.id == SiteSetting.discord_bot_announcement_channel_id.to_i)
            # Copy the message to the assigned Discourse announcement Topic if assigned in plugin settings
            discourse_announcement_topic = Topic.find_by(id: SiteSetting.discord_bot_discourse_announcement_topic_id.to_i)
            unless discourse_announcement_topic.nil?
              new_post = PostCreator.create!(posting_user, raw: raw, topic_id: discourse_announcement_topic.id, skip_validations: true)
            end
          end
        end
      end
    end
  end
end
