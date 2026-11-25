# Jenkins + GitHub Actions

!!! abstract "本章重點"

    CI 工具負責在每次提交時自動建置、測試與打包。本章分別示範 Jenkins Pipeline 與 GitHub Actions Workflow 的寫法，並比較兩者適合的情境。

## Jenkins Pipeline

```groovy
// Jenkinsfile（放在項目根目錄）
pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: maven
      image: maven:3.9.5-eclipse-temurin-17-alpine
      command: ['sleep', 'infinity']
      resources:
        requests:
          cpu: '500m'
          memory: '1Gi'
    - name: docker
      image: docker:24-dind
      securityContext:
        privileged: true
      volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
  volumes:
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
"""
        }
    }

    environment {
        APP_NAME        = 'myapp'
        HARBOR_REGISTRY = 'harbor.example.com'
        HARBOR_REPO     = "${HARBOR_REGISTRY}/backend/${APP_NAME}"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        K8S_NAMESPACE   = 'production'
        HARBOR_CREDS    = credentials('harbor-credentials')
        KUBECONFIG      = credentials('k8s-config')
        SONAR_TOKEN     = credentials('sonar-token')
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
                    echo "Building: ${APP_NAME}:${IMAGE_TAG}"
                }
            }
        }

        stage('Code Analysis') {
            parallel {
                stage('Unit Test') {
                    steps {
                        container('maven') {
                            sh 'mvn test --no-transfer-progress'
                        }
                    }
                    post {
                        always {
                            junit 'target/surefire-reports/*.xml'
                            jacoco(
                                execPattern: 'target/*.exec',
                                minimumLineCoverage: '80'
                            )
                        }
                    }
                }

                stage('SonarQube') {
                    steps {
                        container('maven') {
                            withSonarQubeEnv('SonarQube') {
                                sh """
                                    mvn sonar:sonar \
                                        -Dsonar.projectKey=${APP_NAME} \
                                        -Dsonar.token=${SONAR_TOKEN} \
                                        --no-transfer-progress
                                """
                            }
                        }
                    }
                }

                stage('Security Scan') {
                    steps {
                        container('maven') {
                            sh 'mvn dependency-check:check -DfailBuildOnCVSS=7 --no-transfer-progress'
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build & Push Image') {
            steps {
                container('docker') {
                    sh """
                        echo ${HARBOR_CREDS_PSW} | \
                            docker login ${HARBOR_REGISTRY} \
                            -u ${HARBOR_CREDS_USR} \
                            --password-stdin

                        DOCKER_BUILDKIT=1 docker build \
                            --cache-from ${HARBOR_REPO}:cache \
                            --build-arg BUILDKIT_INLINE_CACHE=1 \
                            -t ${HARBOR_REPO}:${IMAGE_TAG} \
                            -t ${HARBOR_REPO}:latest \
                            .

                        docker push ${HARBOR_REPO}:${IMAGE_TAG}
                        docker push ${HARBOR_REPO}:latest
                        docker push ${HARBOR_REPO}:cache
                    """
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                container('maven') {
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} \
                            set image deployment/${APP_NAME}-deployment \
                            ${APP_NAME}=${HARBOR_REPO}:${IMAGE_TAG} \
                            -n staging

                        kubectl --kubeconfig=${KUBECONFIG} \
                            rollout status deployment/${APP_NAME}-deployment \
                            -n staging --timeout=300s
                    """
                }
            }
        }

        stage('Integration Test') {
            steps {
                container('maven') {
                    sh """
                        mvn verify \
                            -Pintegration-test \
                            -Dapp.url=http://myapp-service.staging.svc.cluster.local \
                            --no-transfer-progress
                    """
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: "確認部署 ${APP_NAME}:${IMAGE_TAG} 到生產環境？",
                          ok: "部署！",
                          submitter: "tech-lead,devops-team"
                }

                container('maven') {
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} \
                            set image deployment/${APP_NAME}-deployment \
                            ${APP_NAME}=${HARBOR_REPO}:${IMAGE_TAG} \
                            -n production

                        kubectl --kubeconfig=${KUBECONFIG} \
                            rollout status deployment/${APP_NAME}-deployment \
                            -n production --timeout=300s

                        kubectl --kubeconfig=${KUBECONFIG} \
                            annotate deployment/${APP_NAME}-deployment \
                            kubernetes.io/change-cause="Jenkins Build #${BUILD_NUMBER}: ${IMAGE_TAG}" \
                            -n production
                    """
                }
            }
        }
    }

    post {
        success {
            slackSend(
                color: 'good',
                message: "✅ ${APP_NAME}:${IMAGE_TAG} 部署成功！\n${BUILD_URL}"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "❌ ${APP_NAME} 建置失敗！\n${BUILD_URL}"
            )
            script {
                if (env.BRANCH_NAME == 'main') {
                    container('maven') {
                        sh """
                            kubectl --kubeconfig=${KUBECONFIG} \
                                rollout undo deployment/${APP_NAME}-deployment \
                                -n production
                        """
                    }
                }
            }
        }
        always {
            cleanWs()
        }
    }
}
```

## GitHub Actions Workflow

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  release:
    types: [published]

env:
  JAVA_VERSION: '17'
  REGISTRY:     ghcr.io
  IMAGE_NAME:   ${{ github.repository }}

jobs:
  # ══════════════════════════════════════
  # Job 1：測試與程式碼品質
  # ══════════════════════════════════════
  test:
    name: 🧪 Test & Quality
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: testpassword
          MYSQL_DATABASE: testdb
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd="redis-cli ping"
          --health-interval=10s

    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: ☕ Setup Java
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          cache: maven

      - name: 🧪 Run Tests
        run: |
          mvn test \
            -Dspring.profiles.active=test \
            -Dspring.datasource.url=jdbc:mysql://localhost:3306/testdb \
            -Dspring.redis.host=localhost \
            --no-transfer-progress

      - name: 📊 Upload Coverage Report
        uses: codecov/codecov-action@v3
        with:
          files: target/site/jacoco/jacoco.xml
          fail_ci_if_error: true
          minimum_coverage: 80

      - name: 🔍 SonarQube Analysis
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN:  ${{ secrets.SONAR_TOKEN }}
        run: |
          mvn sonar:sonar \
            -Dsonar.projectKey=myapp \
            -Dsonar.host.url=https://sonar.example.com \
            --no-transfer-progress

  # ══════════════════════════════════════
  # Job 2：建置 Docker Image
  # ══════════════════════════════════════
  build:
    name: 🐳 Build & Push Image
    needs: test
    runs-on: ubuntu-latest

    outputs:
      image-tag:    ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}

    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 🔑 Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 🏷️ Docker Metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=pr
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=sha-

      - name: 🛠️ Setup Buildx
        uses: docker/setup-buildx-action@v3

      - name: 🐳 Build & Push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          platforms: linux/amd64,linux/arm64
          cache-from: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:cache
          cache-to:   type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:cache,mode=max

      - name: 🛡️ Container Security Scan（Trivy）
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:sha-${{ github.sha }}
          format:    'sarif'
          output:    'trivy-results.sarif'
          severity:  'CRITICAL,HIGH'
          exit-code: '1'

  # ══════════════════════════════════════
  # Job 3：部署到 Staging
  # ══════════════════════════════════════
  deploy-staging:
    name: 🚀 Deploy to Staging
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: ⚙️ Setup kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.28.0'

      - name: 🔑 Configure K8s
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_STAGING }}" | base64 -d > ~/.kube/config

      - name: 🚀 Deploy to Staging
        run: |
          IMAGE="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:sha-${{ github.sha }}"
          kubectl set image deployment/myapp-deployment myapp=${IMAGE} -n staging
          kubectl rollout status deployment/myapp-deployment -n staging --timeout=300s

      - name: 🧪 Smoke Test
        run: |
          sleep 30
          curl -f https://staging.example.com/actuator/health || exit 1

  # ══════════════════════════════════════
  # Job 4：部署到生產（只有 Release）
  # ══════════════════════════════════════
  deploy-production:
    name: 🌟 Deploy to Production
    needs: deploy-staging
    runs-on: ubuntu-latest
    if: github.event_name == 'release'

    environment:
      name: production
      url: https://api.example.com

    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: ⚙️ Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: 🔑 Configure K8s
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_PROD }}" | base64 -d > ~/.kube/config

      - name: 🌟 Deploy to Production
        run: |
          IMAGE="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.event.release.tag_name }}"
          kubectl set image deployment/myapp-deployment myapp=${IMAGE} -n production
          kubectl rollout status deployment/myapp-deployment -n production --timeout=300s
          kubectl annotate deployment/myapp-deployment \
            kubernetes.io/change-cause="Release ${{ github.event.release.tag_name }}" \
            -n production

      - name: 📣 Slack Notification
        uses: slackapi/slack-github-action@v1.25.0
        with:
          payload: |
            {
              "text": "✅ *${{ github.repository }}* 已部署到生產！\n版本：${{ github.event.release.tag_name }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```
