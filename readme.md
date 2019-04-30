## install and run

```
# download
git clone https://github.com/grenade/rubberneck.git $GOPATH/src/github.com/grenade/rubberneck && cd $_

# install go dependencies:
go get -u golang.org/x/oauth2/...
go get -u google.golang.org/api/compute/v1
go get -u github.com/aws/aws-sdk-go/aws
go get -u github.com/aws/aws-sdk-go/aws/session
go get -u github.com/aws/aws-sdk-go/service/ec2
go get -u github.com/patrickmn/go-cache

# initialise gcloud credentials:
gcloud_project=windows-workers
gcloud_service_account=releng-gcp-provisioner
gcloud iam service-accounts keys create ~/.gcloud-${gcloud_service_account}-${gcloud_project}.json --iam-account ${gcloud_service_account}@${gcloud_project}.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS=~/.gcloud-${gcloud_service_account}-${gcloud_project}.json

# run:
go run *.go
```
