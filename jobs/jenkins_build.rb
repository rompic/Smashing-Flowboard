# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'

JENKINS_URI = URI.parse('https://<ip>:8080/')
JENKINS_URL = 'https://<hostname>:8080/'

JENKINS_AUTH = {
  'name' => nil,
  'password' => nil
}.freeze

# the key of this mapping must be a unique identifier for your job, the according value must be the name that is specified in jenkins
job_mapping = {
  'master' => { job: 'master' },
  'master_test' => { job: 'master_test' },
  'master_int_test' => { job: 'master_int_test' },
  'master_hw_test' => { job: 'master_hw_test' }
}

def get_test_results(job_name)
  info = get_json_for_job(job_name, 'lastCompletedBuild')
  testresults = info['actions'].find { |el| el['_class'] == 'hudson.tasks.junit.TestResultAction' }
  testresults
end

def get_completion_percentage(job_name)
  build_info = get_json_for_job(job_name)
  prev_build_info = get_json_for_job(job_name, 'lastCompletedBuild')

  return 0 unless build_info['building']

  last_duration = (prev_build_info['duration'] / 1000).round(2)
  current_duration = (Time.now.to_f - build_info['timestamp'] / 1000).round(2)
  return 99 if current_duration >= last_duration

  ((current_duration * 100) / last_duration).round(0)
end

def get_duration_hrs_and_mins(job_name)
  info = get_json_for_job(job_name, 'lastCompletedBuild')
  duration = info['duration']
  hours = duration / (1000 * 60 * 60)
  minutes = duration / (1000 * 60) % 60
  "#{hours}h #{minutes}m"
rescue StandardError
  ''
end

def get_json_for_job(job_name, build = 'lastBuild')
  job_name = URI.encode(job_name)
  http = Net::HTTP.new(JENKINS_URI.host, JENKINS_URI.port)
  request = Net::HTTP::Get.new("/job/#{job_name}/#{build}/api/json")
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  if JENKINS_AUTH['name']
    request.basic_auth(JENKINS_AUTH['name'], JENKINS_AUTH['password'])
  end
  response = http.request(request)
  JSON.parse(response.body)
end

def get_jenkins_link(job_name, build = 'lastBuild')
  JENKINS_URL + "job/#{job_name}/#{build}"
end

job_mapping.each do |title, jenkins_project|
  current_status = nil
  SCHEDULER.every '15m', first_in: 0, allow_overlapping: false do |_job|
    last_status = current_status
    build_info = get_json_for_job(jenkins_project[:job])
    current_status = build_info['result']
    if build_info['building']
      # current_status = "BUILDING"
      # get the build status for the previous build
      build_info = get_json_for_job(jenkins_project[:job], 'lastCompletedBuild')
      current_status = build_info['result']
      percent = get_completion_percentage(jenkins_project[:job])
    elsif jenkins_project[:pre_job]
      pre_build_info = get_json_for_job(jenkins_project[:pre_job])
      current_status = 'PREBUILD' if pre_build_info['building']
      percent = get_completion_percentage(jenkins_project[:pre_job])
    end
    test_results = get_test_results(jenkins_project[:job])
    # for aborted builds we don't get results
    if test_results
      test_results_str = format('failing tests: %<failCount>s / %<totalCount>s', failCount: test_results['failCount'], totalCount: test_results['totalCount'])
    else
      test_results_str = ''
    end
    duration = get_duration_hrs_and_mins(jenkins_project[:job])
    link_to_send = get_jenkins_link(jenkins_project[:job])
    send_event(title, title: title,
                      currentResult: current_status,
                      lastResult: last_status,
                      timestamp: build_info['timestamp'],
                      value: percent,
                      testResults: test_results_str,
                      duration: duration,
                      link: link_to_send)
  end
end
