pipeline {
  agent any

  environment {
    // Change this to whatever repo/namespace you want, e.g.
    //   'cloudseclab/myapp'  -> docker.io/cloudseclab/myapp
    //   '<acct>.dkr.ecr.<region>.amazonaws.com/myapp' for ECR
    IMAGE_NAME     = 'cloudseclab/myapp'
    CONTAINER_NAME = 'myapp'            // docker container name (no slashes allowed)
    IMAGE_TAG      = "${env.GIT_COMMIT.take(7)}"
    APP_PORT       = '8000'
    ENV_FILE       = '/opt/myapp/.env'  // optional; used only if it exists
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    disableConcurrentBuilds()
  }

  stages {
    stage('Lint & Test') {
      steps {
        sh '''
          python3 -m venv .venv && . .venv/bin/activate
          pip install -q -r requirements-dev.txt
          ruff check app/
          pytest --maxfail=1 --junitxml=report.xml --cov=app
        '''
      }
      post { always { junit 'report.xml' } }
    }

    stage('Build Image') {
      steps {
        sh '''
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
        '''
      }
    }

    stage('Scan container image with Tenable Cloud Security') {
      environment {
        TENABLE_API_TOKEN            = credentials('tenable-api-token')
        TENABLE_API_URL              = 'https://app.tenable.com/'
        TENABLE_CODE_BRANCH          = "${env.CHANGE_BRANCH ?: env.GIT_BRANCH}"
        TENABLE_CODE_COMMIT_HASH     = "${env.GIT_COMMIT}"
        TENABLE_CODE_COMMIT_USER     = "${env.CHANGE_AUTHOR ?: sh(returnStdout: true, script: 'git log -1 --pretty=format:%an').trim()}"
        TENABLE_PIPELINE_RUN_ID      = "${env.BUILD_ID}"
        TENABLE_PIPELINE_RUN_TRIGGER = "${currentBuild.getBuildCauses()[0].shortDescription}"
        TENABLE_PIPELINE_RUN_URL     = "${env.BUILD_URL}"
      }
      steps {
        script {
          // Mount the host Docker socket so the scanner can see the locally built image.
          docker.image('tenable/cloud-security-scanner:latest').inside(
              "--entrypoint='' -u 0 --pull=always -v /var/run/docker.sock:/var/run/docker.sock") {
            sh """
              tenable container-image scan \
                --name ${IMAGE_NAME}:${IMAGE_TAG} \
                --no-color \
                --output-file-formats JUnit \
                --output-path .
            """
            junit skipPublishingChecks: true, testResults: 'results.junit.xml'
          }
        }
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          # keep the currently running image as :previous for rollback
          docker image tag ${IMAGE_NAME}:current ${IMAGE_NAME}:previous 2>/dev/null || true
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:current

          ENV_ARG=""
          [ -f "${ENV_FILE}" ] && ENV_ARG="--env-file ${ENV_FILE}"

          docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
          docker run -d --name ${CONTAINER_NAME} --restart unless-stopped \
            -p ${APP_PORT}:8000 $ENV_ARG ${IMAGE_NAME}:current
        '''
      }
    }

    stage('Verify') {
      steps {
        sh '''
          for i in $(seq 1 10); do
            curl -fs http://localhost:${APP_PORT}/health && echo " OK" && exit 0
            sleep 3
          done
          echo "Health check failed"; exit 1
        '''
      }
    }
  }

  post {
    failure {
      sh '''
        # roll back to the previous image if one exists
        if docker image inspect ${IMAGE_NAME}:previous >/dev/null 2>&1; then
          echo "Rolling back to previous image"
          docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
          ENV_ARG=""
          [ -f "${ENV_FILE}" ] && ENV_ARG="--env-file ${ENV_FILE}"
          docker run -d --name ${CONTAINER_NAME} --restart unless-stopped \
            -p ${APP_PORT}:8000 $ENV_ARG ${IMAGE_NAME}:previous || true
        fi
      '''
      echo 'Build failed.'
    }
    always { cleanWs() }
  }
}
