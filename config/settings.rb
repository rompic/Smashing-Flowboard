# running in visibilityspots/smashing docker container?
$CONFIG_DIR = if Dir.exist?('/config')
               '/config'
             else
               File.dirname(File.expand_path(__FILE__)) + '/../config'
             end

jira_yaml_file = $CONFIG_DIR + '/jira.yaml'
$JIRA_CONFIG = YAML.load(File.new(jira_yaml_file, 'r').read)