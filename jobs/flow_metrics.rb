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

# https://leankanban.com/flow-efficiency-a-great-metric-you-probably-arent-using/
# Based on https://gist.github.com/seize-the-dave/d12bc2f9778362a36576a4cb42b20db2, but we start the time when the ticket is set to In Progress and stop the time when it changes to a different status.
# we also calculate the time until it is released first as wait time.
# e.g.
# new = Open, Prepared
# active = In Progress
# waiting = all other statuses
# done = Released in a Version
new_states = $JIRA_CONFIG[:flow_time_efficiency_work_new_status]
work = $JIRA_CONFIG[:flow_time_efficiency_work_status]

def log_change(log, state, curr_change, prev_change, min_released_date)
  # if the release date is in the past we only calculate up to the release date
  if min_released_date < curr_change
    # puts "min_released_date is < curr_change"
    log[state] += min_released_date - prev_change
    return min_released_date
  end
  log[state] += curr_change - prev_change
  curr_change
end

def append_log(master_log, log)
  log.each_key do |key|
    master_log[key] += log[key]
  end
end

def wait_time(log, new_states, work)
  delta = 0
  log.each do |state, time|
    # don't count new states or work states as wait time
    delta += time unless new_states.include?(state) || work.include?(state)
  end
  delta
end

def work_time(log, work)
  delta = 0
  log.each do |state, time|
    delta += time if work.include? state
  end
  delta
end

last_flow_time_history = []
last_flow_efficiency_history = []

SCHEDULER.every '30m', first_in: 2, allow_overlapping: false do |_job|
  client = JIRA::Client.new(options)
  project = client.Project.find($JIRA_CONFIG[:projectname])

  invalid_values = 0
  master_log = Hash.new(0)
  # select releases in the last months with release date
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
    flow_time_query = format('PROJECT = "%<project>s" AND status = "%<flow_time_efficiency_current_status>s" AND resolution = "%<flow_time_efficiency_resolution>s" AND fixVersion in ("%<releases>s")', project: $JIRA_CONFIG[:projectname], flow_time_efficiency_current_status: $JIRA_CONFIG[:flow_time_efficiency_current_status], flow_time_efficiency_resolution: $JIRA_CONFIG[:flow_time_efficiency_resolution], releases: releases_last_months)
    flow_time_link = "#{options[:site]}/issues/?jql=#{flow_time_query}"
    num_issues = 0
    client.Issue.jql(flow_time_query, max_results: 2000, expand: 'changelog').each do |issue|
      num_issues += 1
      min_released_date = nil
      released = issue.fixVersions.select(&:released)
      released.select! { |e| e.attrs.key?('releaseDate') }
      min_released_date = Time.parse(released.min_by { |x| Date.parse(x.releaseDate) }.releaseDate)

      issue_log = Hash.new(0)

      prev_change = Time.parse(issue.created)

      issue.changelog['histories'].each do |history|
        history['items'].each do |item|
          if item['field'] == 'status'
            prev_change = log_change(issue_log, item['fromString'], Time.parse(history['created']), prev_change, min_released_date)
          end
        end
      end
      curr_status = issue.status.name
      # finally calculate closed until released (If min_released_date is changed to Time.now it could also be calculated for tickets in progress right now)
      log_change(issue_log, curr_status, min_released_date, prev_change, min_released_date)
      issue_work_time = work_time(issue_log, work)
      issue_wait_time = wait_time(issue_log, new_states, work)
      issue_time = issue_work_time + issue_wait_time

      # Only add values to the calculation if there are valid values (e.g. not if tickets are closed immediately)
      if issue_time.positive?
        append_log(master_log, issue_log)
      else
        invalid_values += 1
        # print issue.key," could not calculate flow time and efficiency \n"
      end
    end

    total_work_time = work_time(master_log, work)
    total_wait_time = wait_time(master_log, new_states, work)
    total_time = total_work_time + total_wait_time
    today = Date.today

    flow_time_last_releases_months = ((total_time / 60 / 60 / 24) / (num_issues - invalid_values)).round
    if last_flow_time_history.empty? || today > last_flow_time_history.last[:t]
      last_flow_time_history.shift
      last_flow_time_history << { t: today, val: flow_time_last_releases_months }
    end
    last_flow_time = last_flow_time_history.last[:val]
    send_event('flow_time', current: flow_time_last_releases_months, last: last_flow_time, link: flow_time_link)

    flow_efficiency_last_releases_months = (total_work_time * 100 / total_time).round(2)

    if last_flow_efficiency_history.empty? || today > last_flow_efficiency_history.last[:t]
      last_flow_efficiency_history.shift
      last_flow_efficiency_history << { t: today, val: flow_efficiency_last_releases_months }
    end
    last_flow_efficiency = last_flow_efficiency_history.last[:val]
    flow_efficiency_link = flow_time_link
    send_event('flow_efficiency', current: flow_efficiency_last_releases_months, last: last_flow_efficiency, link: flow_efficiency_link)
  end
end
