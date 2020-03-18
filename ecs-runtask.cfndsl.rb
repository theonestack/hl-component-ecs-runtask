CloudFormation do

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
    StepFunctions_StateMachine('StateMachine') do
      StateMachineName FnSub("${EnvironmentName}-RunTask")
      RoleArn FnGetAtt('StepFunctionRole', 'Arn')
      DefinitionString FnSub(state_machine, {SubnetId: FnSelect(0, Ref('SubnetIds')), Task: {"Ref"=>"Task"}})
    end
  end

end