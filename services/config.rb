
coreo_uni_util_jsrunner "tags-to-notifiers-array" do
  action :run
  json_input '{"stack name":"INSTANCE::stack_name",
  "instance name":"INSTANCE::name",
  "number_of_checks":"STACK::coreo_aws_advisor_s3.advise-s3.number_checks",
  "number_of_violations":"STACK::coreo_aws_advisor_s3.advise-s3.number_violations",
  "number_violations_ignored":"STACK::coreo_aws_advisor_s3.advise-s3.number_ignored_violations",
  "violations": STACK::coreo_aws_advisor_s3.advise-s3.report}'
  function <<-EOH
console.log('we are running');
payloads = {};
notifiers = [];
violations=json_input['violations'];
for (instance_id in violations) {
  tags = violations[instance_id]['tags'];
  for (var i = 0; i < tags.length; i++) {
    if (tags[i]['key'] === 'bv:nexus:team') {
      var aalert = {};
      aalert[instance_id] = violations[instance_id];
      tagVal = tags[i]['value'];
      if (!payloads.hasOwnProperty(tagVal)) {
        payloads[tagVal] = [];
      }
      payloads[tagVal].push(aalert);
    }
  }
}
for (email in payloads) {
  var endpoint = {};
  endpoint['to'] = email;
  var notifier = {};
  notifier['type'] = 'email';
  notifier['send_on'] = 'always';
  notifier['allow_empty'] = 'true';
  notifier['payload_type'] = 'json';
  notifier['endpoint'] = endpoint;
  notifier['payload'] = {};
  notifier['payload']['stack name'] = json_input['stack name'];
  notifier['payload']['instance name'] = json_input['instance name'];
  notifier['payload']['violations'] = payloads[email];
  notifiers.push(notifier);
}
callback(notifiers);
EOH
end

# we are still notifying the entire report to the configured recipient
# in the extends/services/config.rb: coreo_uni_util_notify "advise-s3"
coreo_uni_util_notify "advise-s3-to-tag-values" do
  action :notify
  notifiers 'STACK::coreo_uni_util_jsrunner.tags-to-notifiers-array.return'
end

coreo_uni_util_jsrunner "tags-rollup" do
  action :run
  json_input 'STACK::coreo_uni_util_jsrunner.tags-to-notifiers-array.return'
  function <<-EOH
var rollup = [];
for (var entry=0; entry < json_input.length; entry++) {
  console.log(json_input[entry]);
  if (json_input[entry]['endpoint']['to'].length) {
    console.log('got an email to rollup');
    nViolations = json_input[entry]['payload']['violations'].length;
    rollup.push({'recipient': json_input[entry]['endpoint']['to'], 'nViolations': nViolations});
  }
}
callback(rollup);
EOH
end

coreo_uni_util_notify "advise-s3-rollup" do
  action :notify
  type 'email'
  allow_empty true
  send_on 'always'
  payload '{"stack name":"INSTANCE::stack_name",
  "instance name":"INSTANCE::name",
  "number_of_checks":"STACK::coreo_aws_advisor_s3.advise-s3.number_checks",
  "number_of_violations":"STACK::coreo_aws_advisor_s3.advise-s3.number_violations",
  "number_violations_ignored":"STACK::coreo_aws_advisor_s3.advise-s3.number_ignored_violations",
  "rollup report": STACK::coreo_uni_util_jsrunner.tags-rollup.return}'
  payload_type 'json'
  endpoint ({
      :to => '${AUDIT_AWS_S3_ALERT_RECIPIENT}', :subject => 'CloudCoreo S3 advisor alerts on INSTANCE::stack_name :: INSTANCE::name'
  })
end


