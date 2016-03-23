require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

opts = Slop.parse do |o|
  o.string '-p', '--phraseapp-token', 'Phrase App API Token'
  o.string '-s', '--slack-token', 'Slack API Token'
  o.string '-c', '--channel', 'Channel to post to'
  o.array '--skip-locales', default: []
end

slack_token =  opts["slack-token"]
phraseapp_token =  opts["phraseapp-token"]
channel =  opts["channel"]

raise "-s, -p and -c all be defined" unless slack_token && phraseapp_token && channel

credentials = PhraseApp::Auth::Credentials.new(token: phraseapp_token)
client = PhraseApp::Client.new(credentials)

projects, error = client.projects_list(1, 10)

locale_status = []

projects.each do |project|
  locales, error = client.locales_list(project.id, 1, 50)
  locales.each do |locale|
    unless opts['skip-locales'].include? locale.name
      untranslated_keys, error = client.keys_search(project.id, 1, 100, PhraseApp::RequestParams::KeysSearchParams.new(locale_id: locale.id, q:'translated:false'))
      if untranslated_keys.count > 10
        emotion = 'sob'
      elsif untranslated_keys.count == 0
        emotion = 'relieved'
      else
        emotion = 'worried'
      end
      locale_status << "#{locale.name} has #{untranslated_keys.count} untranslated strings in PhraseApp. #{Emoji.find_by_alias(emotion).raw}"
    end
  end
end

notifier = Slack::Notifier.new slack_token, channel: channel, username: 'PhraseSlack'

notifier.ping locale_status.join("\n")
