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

chart_options = {
  scales: {
    xAxes: [{
      stacked: true
    }],
    yAxes: [{
      ticks: {
        min: 0,
        max: 100
      },
      stacked: true,
      scaleLabel: {
        display: true,
        labelString: format('Percentage %<flow_distribution_status>s', flow_distribution_status: $JIRA_CONFIG[:flow_distribution_status])
      }
    }]
  }
}
months = $JIRA_CONFIG[:months]

background_color = YAML.load(File.new($CONFIG_DIR + '/issue_colors.yaml', 'r').read)
background_color.default = background_color['default']

SCHEDULER.every '30m', first_in: 0, allow_overlapping: false do |_job|
  client = JIRA::Client.new(options)
  issueTypes = client.Project.find($JIRA_CONFIG[:projectname]).issueTypes
  labels = []
  buckets = {}
  first_day_of_current_month = Date.new(Date.today.year, Date.today.mon, 1)
  base_query = format('PROJECT = "%<project>s"', project: $JIRA_CONFIG[:projectname])
  if $JIRA_CONFIG[:flow_distribution_current_status]
    base_query = format('%<base_query>s AND status = "%<flow_distribution_current_status>s"', base_query: base_query, flow_distribution_current_status: $JIRA_CONFIG[:flow_distribution_current_status])
  end
  if $JIRA_CONFIG[:flow_distribution_resolution]
    base_query = format('%<base_query>s AND resolution = "%<flow_distribution_resolution>s"', base_query: base_query, flow_distribution_resolution: $JIRA_CONFIG[:flow_distribution_resolution])
  end
  issueTypes.each do |issuetype|
    buckets[issuetype['name']] = Hash.new(0)
    (months - 1).downto(0) do |i|
      query = format('%<base_query>s AND issuetype="%<issuetypes>s" AND status changed to %<flow_distribution_status>s during (startofMonth(%<month_offset>s),endofMonth(%<month_offset>s))', base_query: base_query, flow_distribution_status: $JIRA_CONFIG[:flow_distribution_status], issuetypes: issuetype['name'], month_offset: -i)
      buckets[issuetype['name']][first_day_of_current_month.prev_month(i)] = client.Issue.jql(query, max_results: 0)
    end
  end

  month_sum = Hash.new 0

  (months - 1).downto(0) do |i|
    labels.push(first_day_of_current_month.prev_month(i).strftime('%B %Y'))
    issueTypes.each do |issuetype|
      month_sum[first_day_of_current_month.prev_month(i)] += buckets[issuetype['name']][first_day_of_current_month.prev_month(i)]
    end
  end

  datasets = []
  issueTypes.each do |issuetype|
    (months - 1).downto(0) do |i|
      if month_sum[first_day_of_current_month.prev_month(i)].positive?
        buckets[issuetype['name']][first_day_of_current_month.prev_month(i)] = (buckets[issuetype['name']][first_day_of_current_month.prev_month(i)].to_f / month_sum[first_day_of_current_month.prev_month(i)] * 100).round(2)
      end
    end
    datasets.push(label: issuetype['name'],
                  data: buckets[issuetype['name']].values,
                  backgroundColor: background_color[issuetype['name']])
  end
  flow_distribution_query = format('%<base_query>s AND status changed to "%<flow_distribution_status>s" during (startofMonth(-%<month_offset>s), endofMonth(0))', base_query: base_query, flow_distribution_status: $JIRA_CONFIG[:flow_distribution_status], month_offset: months - 1)
  link = "#{options[:site]}/issues/?jql=#{flow_distribution_query}"
  send_event('flow_distribution', labels: labels, datasets: datasets, options: chart_options, link: link)
end
