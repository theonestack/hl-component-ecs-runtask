CloudFormation do

  component_name = external_parameters.fetch(:component_name, '')
  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  iam_policies = external_parameters.fetch(:step_function_iam_policies, {})
  unless iam_policies.empty?

    policies = []
    iam_policies.each do |name,policy|
      policies << iam_policy_allow(name,policy['action'],policy['resource'] || '*')
    end

    IAM_Role('StepFunctionRole') do
      AssumeRolePolicyDocument ({
        Statement: [
          {
            Effect: 'Allow',
            Principal: { Service: [ 'states.amazonaws.com' ] },
            Action: [ 'sts:AssumeRole' ]
          }
        ]
      })
      Path '/'
      Policies(policies)
    end

  end

  state_machine = external_parameters.fetch(:state_machine, nil)
  unless state_machine.nil?
    StepFunctions_StateMachine(:StateMachine) do
      StateMachineName FnSub("${EnvironmentName}-#{component_name}-RunTask")
      RoleArn FnGetAtt('StepFunctionRole', 'Arn')
      DefinitionString FnSub(state_machine, {SubnetId: FnSelect(0, Ref('SubnetIds')), Task: {"Ref"=>"Task"}})
    end
  end

  EC2_SecurityGroup(:SecurityGroup) do
    VpcId Ref('VPCId')
    GroupDescription FnSub("${EnvironmentName}-#{external_parameters[:component_name]} ecs runtask")
    Metadata({
      cfn_nag: {
        rules_to_suppress: [
          { id: 'F1000', reason: 'ignore egress for now' }
        ]
      }
    })
  end
  Output(:SecurityGroup) do
    Value(Ref(:SecurityGroup))
    Export FnSub("${EnvironmentName}-#{export}-SecurityGroup")
  end

  ingress_rules = external_parameters.fetch(:ingress_rules, [])
  ingress_rules.each_with_index do |ingress_rule, i|
    EC2_SecurityGroupIngress("IngressRule#{i+1}") do
      Description ingress_rule['desc'] if ingress_rule.has_key?('desc')
      GroupId ingress_rule.has_key?('dest_sg') ? ingress_rule['dest_sg'] : Ref(:SecurityGroup)
      SourceSecurityGroupId ingress_rule.has_key?('source_sg') ? ingress_rule['source_sg'] :  Ref(:SecurityGroup)
      IpProtocol ingress_rule.has_key?('protocol') ? ingress_rule['protocol'] : 'tcp'
      FromPort ingress_rule['from']
      ToPort ingress_rule.has_key?('to') ? ingress_rule['to'] : ingress_rule['from']
    end
  end

  schedule = external_parameters.fetch(:schedule, nil)
  event_pattern = external_parameters.fetch(:event_pattern, nil)

  unless schedule.nil? || event_pattern.nil?
    iam_policies = external_parameters.fetch(:scheduler_iam_policies, {})
    policies = []
    iam_policies.each do |name,policy|
      policies << iam_policy_allow(name,policy['action'],policy['resource'] || '*')
    end
    IAM_Role(:EventBridgeInvokeRole) do
      AssumeRolePolicyDocument ({
        Statement: [
          {
            Effect: 'Allow',
            Principal: { Service: [ 'events.amazonaws.com' ] },
            Action: [ 'sts:AssumeRole' ]
          }
        ]
      })
      Path '/'
      Policies(policies)
    end
    Events_Rule(:Schedule) do
      Name FnSub("${EnvironmentName}-#{component_name}-eventrule")
      Description FnSub("{EnvironmentName} #{component_name} eventrule")
      ScheduleExpression schedule
      EventPattern event_pattern
      Targets [{
        Arn: Ref(:StateMachine),
        Id: 'test',
        RoleArn: FnGetAtt('EventBridgeInvokeRole', 'Arn')
      }]
    end 
  end

end