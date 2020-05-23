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

  data = []

  first_day_of_current_month = Date.new(Date.today.year, Date.today.mon, 1)
  base_query = format('PROJECT = "%<project>s" AND status was in ("%<wip_status>s")', project: $JIRA_CONFIG[:projectname], wip_status: $JIRA_CONFIG[:wip_status].join('", "'))
  (months - 1).downto(0) do |i|
    month_query = "#{base_query} on startofMonth(#{-i})"
    data.push(x: first_day_of_current_month.prev_month(i).to_time.to_i, y: client.Issue.jql(month_query, max_results: 0))
  end
  flow_load_query = "#{base_query} on now()"
  data.push(x: Time.now.to_i, y: client.Issue.jql(flow_load_query, max_results: 0))
  flow_load_link = "#{options[:site]}/issues/?jql=#{flow_load_query}"
  send_event('flow_load', points: data, link: flow_load_link)
end
