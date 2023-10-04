require 'yaml'

describe 'should fail without a task_definition' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/event_pattern.test.yaml")).to be_truthy
    end
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/schedule/ecs-runtask.compiled.yaml") }

  context 'Resource Task' do
    let(:properties) { template["Resources"]["Task"]["Properties"] }

    it 'has property RequiresCompatibilities ' do
      expect(properties["RequiresCompatibilities"]).to eq(['FARGATE'])
    end

    it 'has property NetworkMode ' do
      expect(properties["NetworkMode"]).to eq('awsvpc')
    end

    it 'has property CPU ' do
      expect(properties["Cpu"]).to eq(256)
    end

    it 'has property Memory ' do
      expect(properties["Memory"]).to eq(512)
    end

  end

  context 'Resource StateMachine' do
    let(:properties) { template["Resources"]["StateMachine"]["Properties"] }

    it 'has property StateMachineName' do
      expect(properties["StateMachineName"]).to eq({"Fn::Sub"=>"${EnvironmentName}-ecs-runtask-RunTask"})
    end

    it 'has property RoleArn' do
      expect(properties["RoleArn"]).to eq({"Fn::GetAtt" => ["StepFunctionRole", "Arn"]})
    end

    it 'has property DefinitionString' do
      expect(properties["DefinitionString"]).not_to be_nil
    end
  end

  context 'Resource Schedule' do
    let(:properties) { template["Resources"]["Schedule"]["Properties"] }

    it 'has property Name' do
      expect(properties["Name"]).to eq({"Fn::Sub"=>"${EnvironmentName}-ecs-runtask-eventrule"})
    end

    it 'has property Description' do
      expect(properties["Description"]).to eq({"Fn::Sub"=>"{EnvironmentName} ecs-runtask eventrule"})
    end

    it 'has property ScheduleExpression' do
      expect(properties["ScheduleExpression"]).to eq('* * * * *')
    end

    it 'has property Targets' do
      expect(properties["Targets"]).to eq([{
        "Arn"=>{"Ref"=>"StateMachine"},
        "Id"=> {"Fn::Sub"=>"{EnvironmentName}-ecs-runtask-target"},
        "RoleArn"=>{"Fn::GetAtt"=>["EventBridgeInvokeRole", "Arn"]}
      }])
    end

  end


  
end
