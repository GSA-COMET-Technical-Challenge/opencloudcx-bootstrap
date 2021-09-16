<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.41">
  <actions>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobAction plugin="pipeline-model-definition@1.9.1"/>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction plugin="pipeline-model-definition@1.9.1">
      <jobProperties/>
      <triggers/>
      <parameters/>
      <options/>
    </org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction>
  </actions>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.93">
    <script>pipeline {
    agent any

    stages {
        stage(&apos;Checkout&apos;) {
            steps {
                git branch: &apos;main&apos;, credentialsId: &apos;${credentialsId}&apos;, url: &apos;https://github.com/ajn-riva/opencloudcx-kaniko.git&apos;
            }   
        }
        stage(&apos;Build docker image and publish&apos;) {
            steps {
                sh &apos;&apos;&apos;
                $!/bin/bash

                curl -LO &quot;https://dl.k8s.io/release/v${kubectl_version}/bin/linux/amd64/kubectl&quot;
                chmod +x ./kubectl
                ./kubectl apply -f pod.yaml
                ./kubectl wait --for=condition=Ready pod/opencloudcx-app --namespace jenkins --timeout=300s
                &apos;&apos;&apos;
            }
        }
    }
}
</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>