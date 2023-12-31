pipeline {
    agent any
    options {
        ansiColor('xterm')
    }
	parameters {
		string(name: "terra_action", defaultValue: "plan", description: "Terraform action to be performed")
		//string(name: "git_codebase", defaultValue: "git@ec2-18-200-215-85.eu-west-1.compute.amazonaws.com:ibm-admin/sastoaws-infra.git", description: "git location of the terraform config files")
		//string(name: "main_dir_name", defaultValue: "/var/lib/jenkins/workspace/prod/CD_Pipelines/terraform-ecs-ec2", description: "main directory to execute terraform main.tf from")
		string(name: "tf_vars", defaultValue: "", description: "TF vars to be passed in TF command. ex - image_id=ami-abc123")
	}
 	environment {
            AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
            AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {
		stage('Terraform code checkout') { 
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/rstraining4/2024-stocks-app-eks.git']]])
            }
        }
        stage('Terraform action - init') { 
            steps {
				sh ('cd terraform;terraform init')
            }
        }
		stage('Terraform action - plan') { 
			when {
				expression {
					params.terra_action == "plan" || params.terra_action == "apply"
				}
			}
            steps {
				sh "cd terraform;pwd"
					script {
						if(params.tf_vars == "") {
							sh "cd terraform;terraform plan"				
						}
						else{
							sh 'terraform plan -var="$tf_vars"'				
						
					}
					
				}
            }
        }
		stage('Terraform action - apply') { 
			when {
				expression {
					params.terra_action == "apply"
				}
			}
            steps {
				sh "cd terraform;pwd"
					script {
						if(params.tf_vars == "") {
							sh "cd terraform;terraform apply --auto-approve"				
						}
						else{
							sh 'cd terraform;terraform apply -var="$tf_vars" --auto-approve'				
						
					}
				}
            }
        }
		stage('Terraform action - destroy') { 
			when {
				expression {
					params.terra_action == "destroy"
				}
			}
            steps {
					sh "cd terraform;pwd"
					sh "cd terraform;terraform plan --destroy"
					sh "cd terraform;terraform destroy --auto-approve"
				
            }
        }
    }
}
