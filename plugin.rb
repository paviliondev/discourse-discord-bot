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

  def run_bot
    bot = Discordrb::Commands::CommandBot.new token: SiteSetting.discord_bot_token, prefix: '!'
    bot.bucket :admin_tasks, limit: 3, time_span: 60, delay: 10

    bot.ready do |event|
      puts "Logged in as #{bot.profile.username} (ID:#{bot.profile.id}) | #{bot.servers.size} servers"
      bot.send_message(SiteSetting.discord_bot_admin_channel_id, "The Discourse admin bot has started his shift!")
    end

    # '!disckick' - a command to kick members beneath a certain trust level on Discourse

    bot.command(:disckick, min_args: 0, max_args: 1, bucket: :admin_tasks, rate_limit_message: 'Hold on cow(girl/boy), rate limit hit!', required_roles: [SiteSetting.discord_bot_admin_role_id], description: 'Block users whose trust level is below a certain integer on discourse') do |event, min_trust_level|

      if !min_trust_level then min_trust_level = 3 end

      discordusers = []

      event.respond "Discourse Kick:  Starting.  Minimum Trust Level = #{min_trust_level.to_s}"
      event.respond "Discourse Kick:  Starting.  Please be patient, I'm rate limited to respect Discord services."
      event.respond "Discourse Kick:  Preparing list of users who also have a registered account on Discord ..."

      builder = DB.build("select * from user_associated_accounts /*where*/")
      builder.where("provider_name = :provider_name", provider_name: "discord")
      builder.query.each do |t|
        discordusers << {discord_user_id: t.user_id, provider_uid: t.provider_uid}
      end

      event.respond "Discourse Kick:  Determining user trust levels ..."

      discordusers.each do |user|
        trustuser = User.find_by(id: user[:discord_user_id])
        user[:trust_level] = trustuser[:trust_level]
      end

      event.respond "Discourse Kick:  Compiling list of untrusted users ..."

      untrusted_users = discordusers.select do |user|
          user[:trust_level].to_i < min_trust_level.to_i
      end

      bot_profile = bot.profile.on(event.server)
      can_do_the_magic_dance = bot_profile.permission?(:kick_members)

      if can_do_the_magic_dance == true

        ut_count = untrusted_users.count

        if ut_count > 0
          untrusted_users.each_with_index do |user, index|
            user_id = user[:provider_uid]
            event.server.kick(user_id.to_s, "Kicked for not having sufficient trust level on the linked Discourse site")
            event.respond "Discourse Kick:  [#{index + 1}/#{ut_count}] <@#{user_id.to_s}> has been kicked for having insufficient trust level on the linked Discourse site"
            sleep(SiteSetting.discord_bot_rate_limit_delay)
            rescue => e
              event.respond 'Discourse Kick:  The user you are trying to kick has a role higher than/equal to me.'
              bot.send_message(SiteSetting.discord_bot_admin_channel_id, "ERROR on server #{event.server.name} (ID: #{event.server.id}) for command `^kick`, `#{e}`")
          end
        else
          event.respond 'Discourse Kick:  Great news!  There were no users below the specified or default trust level!'
        end
      else
        event.respond 'Discourse Kick:  Sorry, but I do not have the "Kick Members" permission'
      end

      event.respond "Discourse Kick:  I'm done with the dirty work!"
    end

    # '!discsync' - a command to pull all the groups that Discord using members are a member of and set them up on Discord inc. adding those Roles to users accordingly

    bot.command(:discsync, min_args: 0, max_args: 3, bucket: :admin_tasks, rate_limit_message: 'Hold on cow(girl/boy), rate limit hit!', required_roles: [SiteSetting.discord_bot_admin_role_id], description: 'Block users whose trust level is below a certain integer on discourse') do |event, clean_house, max_group_visibility, include_automated_groups|

      if !clean_house then clean_house = false end
      if !max_group_visibility then max_group_visibility = 0 end
      if !include_automated_groups then include_automated_groups_args = false end

      discord_users = []
      eligible_discourse_groups = []
      discourse_groups = []
      discord_roles =[]
      ug_list = []

      event.respond "Discourse Sync:  Starting.  Please be patient, I'm rate limited to respect Discord services."
      event.respond "Discourse Sync:  Checking if there are any eligible groups for sync ..."

      eligiblegroupbuilder = DB.build("select id from groups /*where*/")
      eligiblegroupbuilder.where("visibility_level <= :visibility", visibility: max_group_visibility.to_i)
      unless include_automated_groups.to_s.downcase == "true" then eligiblegroupbuilder.where("automatic = false") end

      event.respond "Discourse Sync: #{eligiblegroupbuilder.query.count} eligible group(s) were found"

      unless eligiblegroupbuilder.query.count == 0

        eligiblegroupbuilder.query.each do |g|
          eligible_discourse_groups << g.id
        end

        event.respond "Discourse Sync:  Preparing list of users who also have a registered account on Discord ..."

        builder = DB.build("select * from user_associated_accounts /*where*/")
        builder.where("provider_name = :provider_name", provider_name: "discord")
        builder.query.each do |t|
          discord_users << {discourse_user_id: t.user_id, discord_uid: t.provider_uid}
        end

        event.respond "Discourse Sync:  Preparing list of groups that users who have a registered account on Discord belong to on Discourse ..."

        discord_users.each do |user|
          groupbuilder = DB.build("select group_id from group_users /*where*/")
          groupbuilder.where("user_id = :user_id", user_id: user[:discourse_user_id])
          groupbuilder.query.each do |g|
            if eligible_discourse_groups.include? g.group_id
              discourse_groups |= [discourse_group_id: g.group_id]
              ug_entry = {discourse_user_id: user[:discourse_user_id], discord_uid: user[:discord_uid], discourse_group_id: g.group_id}
              ug_list << ug_entry
            end
          end
          userbuilder = DB.build("select username from users /*where*/ limit 1")
          userbuilder.where("id = :user_id", user_id: user[:discourse_user_id])
          userbuilder.query.each do |un|
            ug_list.each do |ug|
              if ug[:discourse_user_id] == user[:discourse_user_id]
                ug[:discourse_username] = un.username
              end
            end
          end
        end

        event.respond "Discourse Sync: #{discourse_groups.length} eligible group(s) were found with Discord users"

        unless discourse_groups.length == 0

          event.respond "Discourse Sync:  Retrieving list of roles from Discord server ..."

          event.server.roles.each do |r|
            discord_roles << {name: r.name, id: r.id}
          end

          discourse_groups.each do |g|
            builder = DB.build("select name from groups /*where*/ limit 1")
            builder.where("id = :group_id", group_id: g[:discourse_group_id])
            builder.query.each do |n|
              g[:discourse_name] = n.name
            end
          end

          if clean_house.to_s.downcase == "true"

            event.respond "Discourse Sync:  Deleting existing mapping roles ..."

            discourse_groups_count = discourse_groups.count

            discourse_groups.each_with_index do |g, index|

              event.respond "Discourse Sync:  [#{index + 1}/#{discourse_groups_count}] Attempting to delete Role"

              if !discord_roles.detect{|r| r[:name] == g[:discourse_name] }.nil?
                role_id = discord_roles.detect{|r| r[:name] == g[:discourse_name] }[:id]
              else
                role_id = nil
              end

              unless role_id.nil?
                begin
                  event.server.role(role_id).delete("Discourse Sync Cleanup")
                  event.respond "Discourse Sync:  Role '#{g[:discourse_name]}' deleted as part of cleanup"
                  sleep(SiteSetting.discord_bot_rate_limit_delay)
                rescue => e
                  event.respond 'Discourse Sync:  I dont appear to have rights to do this though!'
                  bot.send_message(SiteSetting.discord_bot_admin_channel_id, "ERROR on server #{event.server.name} (ID: #{event.server.id}) for command `^role deletion`, `#{e}`")
                end
              end
            end
          end

          event.respond "Discourse Sync:  Creating missing Roles on Discord server ..."

          discord_roles = []

          event.server.roles.each do |r|
            discord_roles << {name: r.name, id: r.id}
          end

          discourse_groups_count = discourse_groups.count

          discourse_groups.each_with_index do |g, index|

            event.respond "Discourse Sync:  [#{index + 1}/#{discourse_groups_count}] Attempting to create Role for #{g[:discourse_name]}"

            if !discord_roles.any?{|hash| hash[:name] == g[:discourse_name]}
            begin
              event.server.create_role(name: g[:discourse_name])
              event.respond "Discourse Sync:  Role '#{g[:discourse_name]}' created!"
            rescue => e
              event.respond 'Discourse Sync:  I dont appear to have rights to create Roles!'
              bot.send_message(SiteSetting.discord_bot_admin_channel_id, "ERROR on server #{event.server.name} (ID: #{event.server.id}) for command `^role create`, `#{e}`")
            end
            else
              event.respond "Discourse Sync:  Role '#{g[:discourse_name]}' already exists!"
            end

            sleep(SiteSetting.discord_bot_rate_limit_delay)
          end

          discord_roles = []

          event.server.roles.each do |r|
            discord_roles << {name: r.name, id: r.id}
          end

          event.respond "Discourse Sync:  Building user role mapping ..."

          ug_list.each do |ug|
            entrybuilder = DB.build("select name from groups /*where*/ limit 1")
            entrybuilder.where("id = :group_id", group_id: ug[:discourse_group_id])

            entrybuilder.query.each do |n|
              ug[:discourse_group_name] = n.name
            end

            discord_roles.each do |dr|
              if dr[:name] == ug[:discourse_group_name]
                ug[:discord_group_id] = dr[:id]
              end
            end
          end

          event.respond "Discourse Sync:  Adding users to roles ..."

          ug_count = ug_list.count
          ug_list.each_with_index do |ug, index|
            event.respond "Discourse Sync:  [#{index + 1}/#{ug_count}] Adding member '#{ug[:discourse_username]}' to '#{ug[:discourse_group_name]}'"
            event.server.member(ug[:discord_uid]).add_role(ug[:discord_group_id])
            sleep(SiteSetting.discord_bot_rate_limit_delay)
            rescue => e
              event.respond 'Discourse Sync:  I dont appear to have rights to do this though!'
              bot.send_message(SiteSetting.discord_bot_admin_channel_id, "ERROR on server #{event.server.name} (ID: #{event.server.id}) for command `^add_role`, `#{e}`")
          end

          event.respond "Discourse Sync:  DONE!"
        else
          event.respond "Discourse Sync:  No users were found in elibigle groups for sync using provided or default criteria!"
        end
      else
        event.respond "Discourse Sync:  No eligible groups for sync using provided or default criteria!"
      end
    end

    bot.message(with_text: 'Ping!' ) do |event|
      event.respond 'Pong!'
    end

    bot.run

  end

    bot_thread = Thread.new do
      begin
        run_bot
      rescue Exception => ex
        Rails.logger.error("Discord Bot: There was a problem: #{ex}")
      end
    end

    STDERR.puts '---------------------------------------------------'
    STDERR.puts 'Bot should now be spawned, say "Ping!" on Discord!'
    STDERR.puts '---------------------------------------------------'
    STDERR.puts '(-------      If not check logs          ---------)'
end
