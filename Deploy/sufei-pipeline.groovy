def version = "${env.BUILD_NUMBER}"
node('docker') {
    stage 'Checkout'
    git changelog: false, poll: false, url: 'http://192.168.33.100:10080/root/sufei-demo.git'

    stage 'Build jar'
    def server = Artifactory.server 'artifactory'
    def rtGradle = Artifactory.newGradleBuild()
    rtGradle.useWrapper = true
    rtGradle.deployer server: server, repo: 'maven'

    def gradleVersion = '-Pversion=' + version

    rtGradle.run switches: gradleVersion, tasks: 'build'

    stage 'QA'
    withSonarQubeEnv('sonar') {
        rtGradle.run switches: gradleVersion + ' --info', tasks: 'sonarqube'
    }

    sleep 10

    def qg = waitForQualityGate()
    if (qg.status != 'OK') {
       error "Pipeline aborted due to quality gate failure: ${qg.status}"
    }

    stage 'Publish jar'
    def buildInfo = rtGradle.run switches: gradleVersion, tasks: 'build artifactoryPublish'

    stage 'Publish docker'
    sh "curl -o app.jar http://artifactory:8081/artifactory/maven/demo/${version}/demo-${version}.jar"
    docker.withServer('tcp://socatdockersock:2375') {
       docker.withRegistry('http://docker.artifactory:8000') {
            docker.build("demo").push("${version}")
       }
    }
}

node('docker') {
  stage 'post-deploy Preprod'
  docker.withServer('tcp://socatdockersock:2375') {
    sh """docker run --net `docker network ls | grep jenkinspipeline | grep default | awk '{print \$2}'` \
    --name demo${version} -d -p 10080 docker.artifactory:8000/demo:${version}"""
    
  }

  stage 'deploy check'
  def checkCommand = createCheckCommand(version)

  stage 'Post-deploy Prod'
  docker.withServer('tcp://192.168.33.201:2375') {
    sh """docker service ls | grep demo && docker service update --image docker.artifactory:8000/demo:${version} demo ||  docker service create --name demo --replicas 2 -p 10080:10080 docker.artifactory:8000/demo:${version}"""
  }
  sh """curl http://192.168.33.201:8500/v1/agent/service/register -d '{"ID":"demo","name":"demo","Tags":["production"], "Address":"192.168.33.201", "Port":10080}' """
  sh """curl http://192.168.33.202:8500/v1/agent/service/register -d '{"ID":"demo","name":"demo","Tags":["production"], "Address":"192.168.33.202", "Port":10080}' """
  
  
  def i = 0

  try {
    waitUntil {
      try {
        sh "${checkCommand}"
        true
      } catch(error) {
        if (i > 1) {
          currentBuild.result = 'FAILURE'
          return true
        }
        sleep 10
        currentBuild.result = 'SUCCESS'
        false
      }
    }
  } finally {
    stage 'Finalize'
    docker.withServer('tcp://socatdockersock:2375') {
      sh "docker rm -f demo${version}"
      sh "docker rmi -f docker.artifactory:8000/demo:${version}"
    }
  }
  
  
}

def createCheckCommand(version) {
  return "curl http://demo${version}:10080/health"
}