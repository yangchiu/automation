# automation

```commandline
docker build -t automation .
docker run -it -e TF_VAR_name_prefix=yangchiu-cluster-2 -e TF_VAR_aws_access_key=$TF_VAR_aws_access_key -e TF_VAR_aws_secret_key=$TF_VAR_aws_secret_key automation /bin/bash
```