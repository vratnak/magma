#!/usr/bin/env bash
################################################################################
# Copyright 2022 The Magma Authors.

# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

set -euo pipefail

usage() {
  cat <<EOF
generateAPIFromSwaggerForTypeScript.sh
 — generates TypeScript NMS API bindings for swagger spec

   Usage:
     generateAPIFromSwaggerForTypeScript.sh [-f] <input> <output>

   Options:

     -i swagger.yml file
     -o Output directory for ts bindings
     -f Overwrite files without confirmation

     <input>   Input swagger.yml file to read.
     <output>   Output directory for js bindings.
EOF
  exit 2
}

FORCE=false
INPUT=""
OUTPUT=""
while getopts 'hfi:o:' option; do
  case "$option" in
    f) FORCE=true ;;
    i) INPUT="${OPTARG}" ;;
    o) OUTPUT="${OPTARG}" ;;
    h | *) usage ;;
  esac
done

[[ -z "${INPUT}" ]] || [[ -z "${OUTPUT}" ]] && usage

if [ "$FORCE" = false ] && [ -d "${OUTPUT}"  ] ; then
    read -r -p "Are you sure you want to overwrite all files in ${OUTPUT} (y/N)? " REPLY
    if [[ !  $REPLY =~ ^[Yy]$ ]]
    then
        exit 1
    fi
fi

(set -x; yarn --silent openapi-generator-cli version-manager set 6.0.0)
(set -x;
yarn --silent openapi-generator-cli generate -i "${INPUT}" --output "${OUTPUT}" --skip-validate-spec --additional-properties=useSingleRequestParameter=true -g typescript-axios)

addHeader() {
  local file="$1"
  TEMPORARY_FILE=$(mktemp)
  cat <<EOF > "${TEMPORARY_FILE}"
/**
 * Copyright 2022 The Magma Authors.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @generated
 * This file is generated by "nms/scripts/generateAPIFromSwaggerForTypeScript.sh".
 */
$(cat "${file}")
EOF
  mv "${TEMPORARY_FILE}" "${file}"
}

for file in "${OUTPUT}"/*.ts; do
  addHeader "${file}"
done

# Workaround for https://github.com/OpenAPITools/openapi-generator/issues/11746
sed -i 's/Set<string>/Array<string>/g' "${OUTPUT}/api.ts"