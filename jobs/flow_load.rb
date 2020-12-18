# frozen_string_literal: true

require 'date'
require 'jira-ruby'
require 'time'
require 'yaml'

options = {
  username: $JIRA_CONFIG[:username],
  password: $JIRA_CONFIG[:password],
  site: $JIRA_CONFIG[:site],
  context_path: '',
  auth_type: :basic
}

months = $JIRA_CONFIG[:months]

SCHEDULER.every '30m', first_in: 0, allow_overlapping: false do |_job|
  client = JIRA::Client.new(options)
  project = client.Project.find($JIRA_CONFIG[:projectname])
  releases = project.versions
  # filter certain releases
  releases.reject!{ |e| $JIRA_CONFIG[:release_filter].any? { |f| e.name.downcase.include?(f) } }
  unreleased_releases = releases.reject{ |e| e.attrs.key?('releaseDate') }.reject{ |e| e.archived }
  
  data = []

  first_day_of_current_month = Date.new(Date.today.year, Date.today.mon, 1)
  base_query = format('PROJECT = "%<project>s" AND (status was in ("%<wip_status>s")', project: $JIRA_CONFIG[:projectname], wip_status: $JIRA_CONFIG[:wip_status].join('", "'))
  (months - 1).downto(0) do |i|
    releases_not_released_at_this_point_in_time = releases.select{ |e| e.attrs.key?('releaseDate') }.select { |e| Date.parse(e.releaseDate) >= first_day_of_current_month.prev_month(i)}
    relevant_releases = unreleased_releases + releases_not_released_at_this_point_in_time
    if relevant_releases.empty?
      month_query = format('%<base_query>s on startofMonth(%<month_offset>s))',base_query: base_query, month_offset: -i)
    else
      relevant_releases_string = relevant_releases.map(&:name).join('","')
      month_query = format('%<base_query>s on startofMonth(%<month_offset>s) or (status = "%<flow_load_current_status>s" AND resolution=%<flow_load_resolution>s AND fixVersion in ("%<releases>s")))',base_query: base_query, month_offset: -i, flow_load_current_status: $JIRA_CONFIG[:flow_load_current_status], flow_load_resolution: $JIRA_CONFIG[:flow_load_resolution], releases: relevant_releases_string)
    end
    
    data.push(x: first_day_of_current_month.prev_month(i).to_time.to_i, y: client.Issue.jql(month_query, max_results: 0))
  end
  flow_load_query = format('%<base_query>s on now() or (status = "%<flow_load_current_status>s" AND resolution=%<flow_load_resolution>s AND fixVersion in unreleasedVersions()))',base_query: base_query, flow_load_current_status: $JIRA_CONFIG[:flow_load_current_status], flow_load_resolution: $JIRA_CONFIG[:flow_load_resolution])
  data.push(x: Time.now.to_i, y: client.Issue.jql(flow_load_query, max_results: 0))
  flow_load_link = "#{options[:site]}/issues/?jql=#{flow_load_query}"
  send_event('flow_load', points: data, link: flow_load_link)
end
