# frozen_string_literal: true

require 'date'
require 'jira-ruby'
require 'yaml'

options = {
  username: $JIRA_CONFIG[:username],
  password: $JIRA_CONFIG[:password],
  site: $JIRA_CONFIG[:site],
  context_path: '',
  auth_type: :basic
}

background_color = YAML.load(File.new($CONFIG_DIR + '/issue_colors.yaml', 'r').read)
background_color.default = background_color['default']

chart_options = {
  title: {
    display: true,
    text: format('Last %<months>s Months', months: $JIRA_CONFIG[:months])
  },
  legend: { display: false },
  scales: {
    yAxes: [{
      scaleLabel: {
        display: true,
        labelString: 'Released'
      }
    }]
  }
}

SCHEDULER.every '30m', first_in: 1, allow_overlapping: false do |_job|
  client = JIRA::Client.new(options)
  project = client.Project.find($JIRA_CONFIG[:projectname])

  # select releases in the last months
  releases_last_months = project.versions.select(&:released)
  releases_last_months.select! { |e| e.attrs.key?('releaseDate') }
  releases_last_months.select! { |e| Date.parse(e.releaseDate) >= Date.new(Date.today.year, Date.today.mon, 1).prev_month($JIRA_CONFIG[:months]) }
  releases_last_months.map!(&:name)
  # filter certain releases
  releases_last_months.reject! { |e| $JIRA_CONFIG[:release_filter].any? { |f| e.downcase.include?(f) } }
  releases_last_months = releases_last_months.join('","')

  if releases_last_months.strip.empty?
    puts 'no recent releases found in ' + __FILE__
  else
    flow_velocity_query = format('PROJECT = "%<project>s" AND status = "%<flow_velocity_current_status>s" AND resolution = "%<flow_velocity_resolution>s" AND fixVersion in ("%<releases>s")', project: $JIRA_CONFIG[:projectname], flow_velocity_current_status: $JIRA_CONFIG[:flow_velocity_current_status], flow_velocity_resolution: $JIRA_CONFIG[:flow_velocity_resolution], releases: releases_last_months)
    flow_velocity_link = "#{options[:site]}/issues/?jql=#{flow_velocity_query}"

    data = []
    labels = []
    background_color_list = []
    project.issueTypes.each do |issuetype|
      labels.push(issuetype['name'])
      issue_query = format('%<flow_velocity_query>s AND issuetype="%<issuetypes>s"', flow_velocity_query: flow_velocity_query, issuetypes: issuetype['name'])
      released_num = client.Issue.jql(issue_query, max_results: 0)
      data.push(released_num)
      background_color_list.push(background_color[issuetype['name']])
    end
    datasets = [{ label: format('Last %<months>s Months', months: $JIRA_CONFIG[:months]), data: data, backgroundColor: background_color_list }]
    send_event('flow_velocity', labels: labels, datasets: datasets, options: chart_options, link: flow_velocity_link)
  end
end
