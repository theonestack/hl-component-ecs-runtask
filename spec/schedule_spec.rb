require 'yaml'

describe 'compiled component ecs-runtask' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/schedule.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/schedule/ecs-runtask.compiled.yaml") }
  
  context "Resource" do

    
    context "StepFunctionRole" do
      let(:resource) { template["Resources"]["StepFunctionRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>["states.amazonaws.com"]}, "Action"=>["sts:AssumeRole"]}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"run_task", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"runtask", "Action"=>["ecs:RunTask", "iam:PassRole"], "Resource"=>"*", "Effect"=>"Allow"}]}}, {"PolicyName"=>"manage_task", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"managetask", "Action"=>["ecs:StopTask", "ecs:DescribeTasks"], "Resource"=>"*", "Effect"=>"Allow"}]}}, {"PolicyName"=>"task_events", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"taskevents", "Action"=>["events:PutTargets", "events:PutRule", "events:DescribeRule"], "Resource"=>[{"Fn::Sub"=>"arn:aws:events:${AWS::Region}:${AWS::AccountId}:rule/StepFunctionsGetEventsForECSTaskRule"}], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "StateMachine" do
      let(:resource) { template["Resources"]["StateMachine"] }

      it "is of type AWS::StepFunctions::StateMachine" do
          expect(resource["Type"]).to eq("AWS::StepFunctions::StateMachine")
      end
      
      it "to have property StateMachineName" do
          expect(resource["Properties"]["StateMachineName"]).to eq({"Fn::Sub"=>"${EnvironmentName}-ecs-runtask-RunTask"})
      end
      
      it "to have property RoleArn" do
          expect(resource["Properties"]["RoleArn"]).to eq({"Fn::GetAtt"=>["StepFunctionRole", "Arn"]})
      end
      
      it "to have property DefinitionString" do
          expect(resource["Properties"]["DefinitionString"]).to eq({"Fn::Sub"=>["{\n  \"Comment\": \"\",\n  \"StartAt\": \"Run Task\",\n  \"TimeoutSeconds\": 3600,\n  \"States\": {\n    \"Run Task\": {\n      \"Type\": \"Task\",\n      \"Resource\": \"arn:aws:states:::ecs:runTask.sync\",\n      \"Parameters\": {\n        \"LaunchType\": \"FARGATE\",\n        \"Cluster\": \"${EcsCluster}\",\n        \"TaskDefinition\": \"${Task}\",\n        \"NetworkConfiguration\": {\n          \"AwsvpcConfiguration\": {\n            \"Subnets\": [\"${SubnetId}\"],\n            \"SecurityGroups\": [\"${SecurityGroup}\"],\n            \"AssignPublicIp\": \"DISABLED\"\n          }\n        }\n      },\n      \"Next\": \"Success\",\n      \"Catch\": [\n          {\n            \"ErrorEquals\": [ \"States.ALL\" ],\n            \"Next\": \"Failure\"\n          }\n      ]\n    },\n    \"Success\": {\n      \"Type\": \"Succeed\"\n    },\n    \"Failure\": {\n      \"Type\": \"Fail\"\n    }\n  }\n}", {"SubnetId"=>{"Fn::Select"=>[0, {"Ref"=>"SubnetIds"}]}, "Task"=>{"Ref"=>"Task"}}]})
      end
      
    end
    
    context "SecurityGroup" do
      let(:resource) { template["Resources"]["SecurityGroup"] }

      it "is of type AWS::EC2::SecurityGroup" do
          expect(resource["Type"]).to eq("AWS::EC2::SecurityGroup")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property GroupDescription" do
          expect(resource["Properties"]["GroupDescription"]).to eq({"Fn::Sub"=>"${EnvironmentName}-ecs-runtask ecs runtask"})
      end
      
    end
    
    context "EventBridgeInvokeRole" do
      let(:resource) { template["Resources"]["EventBridgeInvokeRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>["events.amazonaws.com"]}, "Action"=>["sts:AssumeRole"]}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"event_schedule", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"eventschedule", "Action"=>["states:StartExecution"], "Resource"=>[{"Fn::Sub"=>"${StateMachine}"}], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "Schedule" do
      let(:resource) { template["Resources"]["Schedule"] }

      it "is of type AWS::Events::Rule" do
          expect(resource["Type"]).to eq("AWS::Events::Rule")
      end
      
      it "to have property Name" do
          expect(resource["Properties"]["Name"]).to eq({"Fn::Sub"=>"${EnvironmentName}-ecs-runtask-eventrule"})
      end
      
      it "to have property Description" do
          expect(resource["Properties"]["Description"]).to eq({"Fn::Sub"=>"${EnvironmentName} ecs-runtask eventrule"})
      end
      
      it "to have property ScheduleExpression" do
          expect(resource["Properties"]["ScheduleExpression"]).to eq("* * * * *")
      end
      
      it "to have property Targets" do
          expect(resource["Properties"]["Targets"]).to eq([{"Arn"=>{"Ref"=>"StateMachine"}, "Id"=>{"Fn::Sub"=>"${EnvironmentName}-ecs-runtask-target"}, "RoleArn"=>{"Fn::GetAtt"=>["EventBridgeInvokeRole", "Arn"]}}])
      end
      
    end
    
    context "LogGroup" do
      let(:resource) { template["Resources"]["LogGroup"] }

      it "is of type AWS::Logs::LogGroup" do
          expect(resource["Type"]).to eq("AWS::Logs::LogGroup")
      end
      
      it "to have property LogGroupName" do
          expect(resource["Properties"]["LogGroupName"]).to eq({"Ref"=>"AWS::StackName"})
      end
      
      it "to have property RetentionInDays" do
          expect(resource["Properties"]["RetentionInDays"]).to eq(7)
      end
      
    end
    
    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
          expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end
      
      it "to have property ContainerDefinitions" do
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"dummy", "Image"=>{"Fn::Join"=>["", [{"Fn::Sub"=>"apline"}, ":", {"Ref"=>"ecsruntaskTaskVersion"}]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"dummy"}}}])
      end
      
      it "to have property RequiresCompatibilities" do
          expect(resource["Properties"]["RequiresCompatibilities"]).to eq(["FARGATE"])
      end
      
      it "to have property Cpu" do
          expect(resource["Properties"]["Cpu"]).to eq(256)
      end
      
      it "to have property Memory" do
          expect(resource["Properties"]["Memory"]).to eq(512)
      end
      
      it "to have property NetworkMode" do
          expect(resource["Properties"]["NetworkMode"]).to eq("awsvpc")
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end