#!/bin/bash

. ./oci-curl.sh

oci-curl database.eu-frankfurt-1.oraclecloud.com POST ./requestATP.json "/20160918/autonomousDatabases?compartmentId=$TF_VAR_compartment_ocid"
