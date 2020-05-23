# frozen_string_literal: true

require 'date'
require 'jira-ruby'
require 'yaml'

MAX_DAYS_OVERDUE = -31
MAX_DAYS_AWAY = 90

options = {
  username: $JIRA_CONFIG[:username],
  password: $JIRA_CONFIG[:password],
  site: $JIRA_CONFIG[:site],
  context_path: '',
  auth_type: :basic
}

# static events
static_events_file = $CONFIG_DIR + '/timeline_data.yaml'

SCHEDULER.every '1h', first_in: 0 do
  event_config = YAML.load(File.open(static_events_file))
  client = JIRA::Client.new(options)

  project = client.Project.find($JIRA_CONFIG[:projectname])
  nextreleases = project.versions.reject(&:released)
  nextreleases.select! { |e| e.attrs.key?('releaseDate') }

  nextreleases.each do |release|
    release_display_name = release.name
    release_display_name += ' (overdue)' if release.overdue
    event_config[:events] << {
      name: release_display_name,
      date: release.releaseDate,
      background: 'pink'
    }
  end

  if event_config[:events].nil?
    puts 'No events found :('
  else
    events = []
    today = Date.today
    no_event_today = true
    event_config[:events].each do |event|
      days_away = (Date.parse(event[:date]) - today).to_i
      if days_away.negative? && (days_away >= MAX_DAYS_OVERDUE)
        events << {
          name: event[:name],
          date: event[:date],
          background: event[:background],
          opacity: 0.5
        }
      elsif (days_away.zero? || days_away.positive?) && (days_away <= MAX_DAYS_AWAY)
        events << {
          name: event[:name],
          date: event[:date],
          background: event[:background]
        }
      end

      no_event_today = false if days_away.zero?
    end

    if no_event_today
      events << {
        name: 'TODAY',
        date: today.strftime('%d %b %Y'),
        background: 'gold'
      }
    end
    link = "#{options[:site]}/projects/#{$JIRA_CONFIG[:projectname]}?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page&status=unreleased"
    send_event('a_timeline', events: events, link: link)
  end
end
