require 'net/http'
require 'json'
require 'time'

JENKINS_URI = URI.parse("")

JENKINS_AUTH = {
  'name' => "",
  'password' => "" 
}

# the key of this mapping must be a unique identifier for your job, the according value must be the name that is specified in jenkins

# by hi25.shin
# job_mapping의 "job1"는 unqiue value 이고, dashboard에서 사용된다.
# completion_percentage가 정확하게 나타나려면 jenkins 서버 시간과 dashing 서버 시간이 일치해야 함

job_mapping = {
  #'JOB' => { :job => 'BUILD', :pre_job => 'PRE_BUILD'}
  'job1' => { :job => 'smail-integration-test-score-basic'}
}

def get_number_of_failing_tests(job_name)
  info = get_json_for_job(job_name, 'lastCompletedBuild')
  info['actions'][4]['failCount']
end

def get_completion_percentage(job_name)
  build_info = get_json_for_job(job_name)
  prev_build_info = get_json_for_job(job_name, 'lastCompletedBuild')

  return 0 if not build_info["building"]
  last_duration = (prev_build_info["duration"] / 1000).round(2)
  current_duration = (Time.now.to_f - build_info["timestamp"] / 1000).round(2)
  print current_duration
  return 99 if current_duration >= last_duration
  ((current_duration * 100) / last_duration).round(0)
end

def get_json_for_job(job_name, build = 'lastBuild')
  job_name = URI.encode(job_name)
  http = Net::HTTP.new(JENKINS_URI.host, JENKINS_URI.port)
  request = Net::HTTP::Get.new("/job/#{job_name}/#{build}/api/json")
  if JENKINS_AUTH['name']
    request.basic_auth(JENKINS_AUTH['name'], JENKINS_AUTH['password'])
  end
  response = http.request(request)
  JSON.parse(response.body)
end

job_mapping.each do |title, jenkins_project|
  current_status = nil
  SCHEDULER.every '10s', :first_in => 0 do |job|
    last_status = current_status
    print "debug...\n"
    build_info = get_json_for_job(jenkins_project[:job])
    current_status = build_info["result"]

    print build_info["result"]
    print build_info["building"]

    if build_info["building"]
      current_status = "BUILDING"
      percent = get_completion_percentage(jenkins_project[:job])
    elsif jenkins_project[:pre_job]
      pre_build_info = get_json_for_job(jenkins_project[:pre_job])
      current_status = "PREBUILD" if pre_build_info["building"]
      percent = get_completion_percentage(jenkins_project[:pre_job])
    end

    print title
    print current_status
    print last_status
    print percent
    send_event(title, {
      currentResult: current_status,
      lastResult: last_status,
      timestamp: build_info["timestamp"],
      value: percent
    })
    print "sent event\n"
  end
end
