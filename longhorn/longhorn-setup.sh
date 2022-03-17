#!/usr/bin/env bash

set -x

# create and clean tmpdir
TMPDIR="/tmp/longhorn"
mkdir -p ${TMPDIR}
rm -rf "${TMPDIR}/"


LONGHORN_NAMESPACE="longhorn-system"


install_csi_snapshotter_crds(){
    CSI_SNAPSHOTTER_REPO_URL="https://github.com/kubernetes-csi/external-snapshotter.git"
    CSI_SNAPSHOTTER_REPO_BRANCH="master"
    CSI_SNAPSHOTTER_REPO_DIR="${TMPDIR}/k8s-csi-external-snapshotter"

    git clone --single-branch \
              --branch "${CSI_SNAPSHOTTER_REPO_BRANCH}" \
      		  "${CSI_SNAPSHOTTER_REPO_URL}" \
      		  "${CSI_SNAPSHOTTER_REPO_DIR}"

    kubectl apply -f ${CSI_SNAPSHOTTER_REPO_DIR}/client/config/crd \
                  -f ${CSI_SNAPSHOTTER_REPO_DIR}/deploy/kubernetes/snapshot-controller
}


wait_longhorn_status_running(){
  local RETRY_COUNTS=10  # in minutes
	local RETRY_INTERVAL="1m"

    RETRIES=0
    while [[ -n `kubectl get pods -n ${LONGHORN_NAMESPACE} --no-headers | awk '{print $3}' | grep -v Running` ]]; do
        echo "Longhorn is still installing ... re-checking in 1m"
        sleep ${RETRY_INTERVAL}
        RETRIES=$((RETRIES+1))

        if [[ ${RETRIES} -eq ${RETRY_COUNTS} ]]; then echo "Error: longhorn installation timeout"; exit 1 ; fi
    done
}


LONGHORN_MANAGER_REPO_URI="https://github.com/longhorn/longhorn-manager.git"
LONGHORN_MANAGER_BRANCH="v1.2.x"
CUSTOM_LONGHORN_MANAGER_IMAGE="longhornio/longhorn-manager:v1.2.x-head"
CUSTOM_LONGHORN_ENGINE_IMAGE="longhornio/longhorn-engine:v1.2.x-head"
CUSTOM_LONGHORN_UI_IMAGE="longhornio/longhorn-ui:v1.2.x-head"


generate_longhorn_yaml_manifest() {

	LONGHORN_MANAGER_REPO_URI=${LONGHORN_MANAGER_REPO_URI:-"https://github.com/longhorn/longhorn-manager.git"}
	LONGHORN_MANAGER_BRANCH=${LONGHORN_MANAGER_BRANCH:-"master"}
	LONGHORN_MANAGER_REPO_DIR="${TMPDIR}/longhorn-manager"

    CUSTOM_LONGHORN_MANAGER_IMAGE=${CUSTOM_LONGHORN_MANAGER_IMAGE:-"longhornio/longhorn-manager:master-head"}
    CUSTOM_LONGHORN_ENGINE_IMAGE=${CUSTOM_LONGHORN_ENGINE_IMAGE:-"longhornio/longhorn-engine:master-head"}
    CUSTOM_LONGHORN_UI_IMAGE=${CUSTOM_LONGHORN_UI_IMAGE:-"longhornio/longhorn-ui:master-head"}

    CUSTOM_LONGHORN_INSTANCE_MANAGER_IMAGE=${CUSTOM_LONGHORN_INSTANCE_MANAGER_IMAGE:-""}
    CUSTOM_LONGHORN_SHARE_MANAGER_IMAGE=${CUSTOM_LONGHORN_SHARE_MANAGER_IMAGE:-""}
    CUSTOM_LONGHORN_BACKING_IMAGE_MANAGER_IMAGE=${CUSTOM_LONGHORN_BACKING_IMAGE_MANAGER_IMAGE:-""}


	git clone --single-branch \
		      --branch ${LONGHORN_MANAGER_BRANCH} \
			  ${LONGHORN_MANAGER_REPO_URI} \
			  ${LONGHORN_MANAGER_REPO_DIR}

    for FILE in `find "${LONGHORN_MANAGER_REPO_DIR}/deploy/install" -type f -name "*\.yaml" | sort`; do
      cat ${FILE} >> "longhorn.yaml"
      echo "---"  >> "longhorn.yaml"
    done

	# get longhorn default images from yaml manifest
    LONGHORN_MANAGER_IMAGE=`grep -io "longhornio\/longhorn-manager:.*$" "longhorn.yaml"| head -1`
    LONGHORN_ENGINE_IMAGE=`grep -io "longhornio\/longhorn-engine:.*$" "longhorn.yaml"| head -1`
    LONGHORN_UI_IMAGE=`grep -io "longhornio\/longhorn-ui:.*$" "longhorn.yaml"| head -1`
    LONGHORN_INSTANCE_MANAGER_IMAGE=`grep -io "longhornio\/longhorn-instance-manager:.*$" "longhorn.yaml"| head -1`
    LONGHORN_SHARE_MANAGER_IMAGE=`grep -io "longhornio\/longhorn-share-manager:.*$" "longhorn.yaml"| head -1`
    LONGHORN_BACKING_IMAGE_MANAGER_IMAGE=`grep -io "longhornio\/backing-image-manager:.*$" "longhorn.yaml"| head -1`

	# replace longhorn images with custom images
    sed -i 's#'${LONGHORN_MANAGER_IMAGE}'#'${CUSTOM_LONGHORN_MANAGER_IMAGE}'#' "longhorn.yaml"
    sed -i 's#'${LONGHORN_ENGINE_IMAGE}'#'${CUSTOM_LONGHORN_ENGINE_IMAGE}'#' "longhorn.yaml"
    sed -i 's#'${LONGHORN_UI_IMAGE}'#'${CUSTOM_LONGHORN_UI_IMAGE}'#' "longhorn.yaml"

	# replace images if custom image is specified.
	if [[ ! -z ${CUSTOM_LONGHORN_INSTANCE_MANAGER_IMAGE} ]]; then
    	sed -i 's#'${LONGHORN_INSTANCE_MANAGER_IMAGE}'#'${CUSTOM_LONGHORN_INSTANCE_MANAGER_IMAGE}'#' "longhorn.yaml"
	else
		# use instance-manager image specified in yaml file if custom image is not specified
		CUSTOM_LONGHORN_INSTANCE_MANAGER_IMAGE=${LONGHORN_INSTANCE_MANAGER_IMAGE}
	fi

	if [[ ! -z ${CUSTOM_LONGHORN_SHARE_MANAGER_IMAGE} ]]; then
    	sed -i 's#'${LONGHORN_SHARE_MANAGER_IMAGE}'#'${CUSTOM_LONGHORN_SHARE_MANAGER_IMAGE}'#' "longhorn.yaml"
	else
		# use share-manager image specified in yaml file if custom image is not specified
		CUSTOM_LONGHORN_SHARE_MANAGER_IMAGE=${LONGHORN_SHARE_MANAGER_IMAGE}
	fi


	if [[ ! -z ${CUSTOM_LONGHORN_BACKING_IMAGE_MANAGER_IMAGE} ]]; then
    	sed -i 's#'${LONGHORN_BACKING_IMAGE_MANAGER_IMAGE}'#'${CUSTOM_LONGHORN_BACKING_IMAGE_MANAGER_IMAGE}'#' "longhorn.yaml"
	else
		# use backing-image-manager image specified in yaml file if custom image is not specified
		CUSTOM_LONGHORN_BACKING_IMAGE_MANAGER_IMAGE=${LONGHORN_BACKING_IMAGE_MANAGER_IMAGE}
	fi
}


install_longhorn(){
	LONGHORN_MANIFEST_FILE_PATH="${1}"

	kubectl apply -f "${LONGHORN_MANIFEST_FILE_PATH}"
	wait_longhorn_status_running
}


create_longhorn_namespace(){
  kubectl create ns ${LONGHORN_NAMESPACE}
}


install_backupstores(){
  MINIO_BACKUPSTORE_URL="https://raw.githubusercontent.com/longhorn/longhorn-tests/master/manager/integration/deploy/backupstores/minio-backupstore.yaml"
  NFS_BACKUPSTORE_URL="https://raw.githubusercontent.com/longhorn/longhorn-tests/master/manager/integration/deploy/backupstores/nfs-backupstore.yaml"
  kubectl create -f ${MINIO_BACKUPSTORE_URL} \
	             -f ${NFS_BACKUPSTORE_URL}
}


create_aws_secret(){
	AWS_ACCESS_KEY_ID_BASE64=`echo -n "${TF_VAR_aws_access_key}" | base64`
	AWS_SECRET_ACCESS_KEY_BASE64=`echo -n "${TF_VAR_aws_secret_key}" | base64`
	AWS_DEFAULT_REGION_BASE64=`echo -n "us-east-1" | base64`

	yq e -i '.data.AWS_ACCESS_KEY_ID |= "'${AWS_ACCESS_KEY_ID_BASE64}'"' "aws_cred_secrets.yml"
	yq e -i '.data.AWS_SECRET_ACCESS_KEY |= "'${AWS_SECRET_ACCESS_KEY_BASE64}'"' "aws_cred_secrets.yml"
	yq e -i '.data.AWS_DEFAULT_REGION |= "'${AWS_DEFAULT_REGION_BASE64}'"' "aws_cred_secrets.yml"

	kubectl apply -f "aws_cred_secrets.yml" -n ${LONGHORN_NAMESPACE}
}

create_longhorn_ui_nodeport() {
  kubectl apply -f "ui-nodeport.yaml" -n ${LONGHORN_NAMESPACE}
}


main(){
	#create_longhorn_namespace
	#install_backupstores
	# set debugging mode off to avoid leaking aws secrets to the logs.
	# DON'T REMOVE!
	#set +x
	#create_aws_secret
	#set -x
	#install_csi_snapshotter_crds
	#generate_longhorn_yaml_manifest
	#install_longhorn "longhorn.yaml"
  create_longhorn_ui_nodeport
}

main
