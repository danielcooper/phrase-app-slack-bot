require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

opts = Slop.parse do |o|
  o.string '-p', '--phraseapp-token', 'Phrase App API Token'
  o.string '-s', '--slack-token', 'Slack API Token'
  o.string '-c', '--channel', 'Channel to post to'
  o.array '--skip-locales', default: []
  o.array '--skip-projects', default: []
end

slack_token =  opts["slack-token"]
phraseapp_token =  opts["phraseapp-token"]
channel =  opts["channel"]

raise "-s, -p and -c all be defined" unless slack_token && phraseapp_token && channel

credentials = PhraseApp::Auth::Credentials.new(token: phraseapp_token)
client = PhraseApp::Client.new(credentials)

projects, error = client.projects_list(1, 10)

locale_status = []
locale_totals = {}

projects.each do |project|
  unless opts['skip-projects'].include? project.id
    locales, error = client.locales_list(project.id, 1, 50)
    locales.each_with_index do |locale, i|
      unless opts['skip-locales'].include? locale.name
        untranslated_keys, error = client.keys_search(project.id, 1, 100, PhraseApp::RequestParams::KeysSearchParams.new(locale_id: locale.id, q:'translated:false'))
        locale_totals[locale.name] = {} unless locale_totals.has_key?(locale.name)
        locale_totals[locale.name]['total'] = 0 unless locale_totals[locale.name].has_key?('total')
        locale_totals[locale.name]['total'] += untranslated_keys.count
        locale_totals[locale.name]['projects'] = {} unless locale_totals[locale.name].has_key? 'projects'
        locale_totals[locale.name]['projects'][project.name] =  untranslated_keys.count
      end
    end
  end
end

output = []
locale_totals.sort_by{ |k, v| v['total'] * -1 }.to_h.each do |k,v|
  if v['total'] > 0
    output << ":#{k.downcase}: *#{k}*: #{v['total']} untranslated strings (#{v['projects'].keep_if{|pk,pv| pv > 0}.keys.join(', ')})"
  end
end

notifier = Slack::Notifier.new slack_token, channel: channel, username: 'PhraseSlack'
notifier.ping output.join("\n")
