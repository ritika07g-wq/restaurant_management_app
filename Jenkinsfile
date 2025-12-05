pipeline {
    agent any

    stages {

        stage('Clone Repo') {
            steps {
                git branch: 'main', url: 'https://github.com/ritika07g-wq/restaurant_management_app.git'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t flutter_restaurant_app .'
            }
        }

        stage('Docker Run') {
            steps {
                sh 'docker run -d -p 8081:80 flutter_restaurant_app || true'
            }
        }
    }
}
