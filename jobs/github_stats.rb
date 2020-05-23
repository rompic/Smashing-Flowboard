# frozen_string_literal: true

require 'octokit'
require 'date'

URL = 'https://<hostname>'
current_pr_num = 0
Octokit.configure do |c|
  c.auto_paginate = true
  # https://github.com/octokit/octokit.rb#working-with-github-enterprise
  c.api_endpoint = URL + 'api/v3/'
end
access_token = ''
repos = ['yourOrg/yourRepo']
last_pr_num_history = {}

SCHEDULER.every '15m', first_in: 0, allow_overlapping: false do
  today = Date.today
  repos.each do |name|
    last_pr_num_history[name] = [] unless last_pr_num_history.key?(name)
    pull_average_open_time_list = []
    current_pr_num = 0
    Octokit::Client.new(access_token: access_token).pulls(name, state: 'open').each do |pull|
      current_pr_num += 1
      pull_average_open_time_list.push((Time.now - pull.created_at).to_i / (24 * 60 * 60))
    end

    average_pr_open_time = (pull_average_open_time_list.inject { |a, e| a + e }.to_f / pull_average_open_time_list.size).round(2)

    if last_pr_num_history[name].empty? || today > last_pr_num_history[name].last[:t]
      last_pr_num_history[name].shift
      last_pr_num_history[name] << { t: today, val: current_pr_num }
    end
    last_pr_num = last_pr_num_history[name].last[:val]
    send_event(name, current: current_pr_num, last: last_pr_num, link: "#{URL}#{name}/pulls", moreinfo: format('already open for avg. %<average_pr_open_time>s days', average_pr_open_time: average_pr_open_time))
  end
end
