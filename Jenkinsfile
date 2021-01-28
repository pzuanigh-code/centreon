/*
** Variables.
*/
properties([buildDiscarder(logRotator(numToKeepStr: '50'))])
def serie = '21.04'
def maintenanceBranch = "${serie}.x"
env.PROJECT='centreon-web'
if (env.BRANCH_NAME.startsWith('release-')) {
  env.BUILD = 'RELEASE'
} else if ((env.BRANCH_NAME == 'master') || (env.BRANCH_NAME == maintenanceBranch)) {
  env.BUILD = 'REFERENCE'
} else {
  env.BUILD = 'CI'
}
def apiFeatureFiles = []
def featureFiles = []

/*
** Pipeline code.
*/
stage('Source') {
  node {
    environment {
      CENTREON_GPG_FILE = credentials('centreon-gpg')
    }
    sh 'cat $CENTREON_GPG_FILE'
}
