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

options_extern = {
  username: $JIRA_CONFIG[:username],
  password: $JIRA_CONFIG[:password],
  site: $JIRA_CONFIG[:site_extern],
  context_path: '',
  auth_type: :basic
}

last_num_history = {}
$JIRA_CONFIG[:issuecount_mapping].each do |mapping_name, filter|
  SCHEDULER.every '15m', first_in: 0, allow_overlapping: false do
    filter_with_project = format(filter, project: $JIRA_CONFIG[:projectname])
    link = "#{options[:site]}/issues/?jql=#{filter_with_project}"
    today = Date.today
    unless last_num_history.key?(mapping_name)
      last_num_history[mapping_name] = []
    end
    total = JIRA::Client.new(options).Issue.jql(filter_with_project, max_results: 0)
    if last_num_history[mapping_name].empty? || today > last_num_history[mapping_name].last[:t]
      last_num_history[mapping_name].shift
      last_num_history[mapping_name] << { t: today, val: total }
    end
    last = last_num_history[mapping_name].last[:val]

    send_event(mapping_name, current: total, last: last, link: link)
  end
end

last_num_history_ext = {}
$JIRA_CONFIG[:issuecount_mapping_external].each do |mapping_name, filter|
  SCHEDULER.every '15m', first_in: 0 do
    link = "#{options_extern[:site]}/issues/?jql=#{filter}"
    today = Date.today
    unless last_num_history_ext.key?(mapping_name)
      last_num_history_ext[mapping_name] = []
    end
    total = JIRA::Client.new(options_extern).Issue.jql(filter, max_results: 0)
    if last_num_history_ext[mapping_name].empty? || today > last_num_history_ext[mapping_name].last[:t]
      last_num_history_ext[mapping_name].shift
      last_num_history_ext[mapping_name] << { t: today, val: total }
    end
    last = last_num_history_ext[mapping_name].last[:val]

    send_event(mapping_name, current: total, last: last, link: link)
  end
end
