#!/bin/bash

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PYTHON_SOURCE_LOCATIONS=('scripts' 'src/python')

# Setup the environment variables
# shellcheck disable=SC2155
export PYTHONPATH=$PYTHONPATH:$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
# more info: https://mypy.readthedocs.io/en/stable/running_mypy.html#mapping-file-paths-to-modules
export MYPYPATH=$MYPYPATH:src/python/lib

PYLINT_OUTPUT_FILE=$(mktemp)
PYLINT_ERRORS=$(mktemp)
# CITest project is on hold and it needs to be updated before resuming its linter checker
find "${PYTHON_SOURCE_LOCATIONS[@]}" -type f -name "*.py" \! -name "Ortheus.py" \! -name "*citest*.py" \! -path "*/citest/*" -print0 | xargs -0 pylint --rcfile pyproject.toml --verbose | tee "$PYLINT_OUTPUT_FILE"
grep -v "\-\-\-\-\-\-\-\-\-" "$PYLINT_OUTPUT_FILE" | grep -v "Your code has been rated" | grep -v "\n\n" | sed '/^$/d' > "$PYLINT_ERRORS"
! [ -s "$PYLINT_ERRORS" ]
rt1=$?
rm "$PYLINT_OUTPUT_FILE" "$PYLINT_ERRORS"

# CITest project is on hold and it needs to be updated before resuming its static type checker
find "${PYTHON_SOURCE_LOCATIONS[@]}" -type f -name "*.py" \! -name "Ortheus.py" \! -name "*citest*.py" \! -path "*/citest/*" -print0 | xargs -0 mypy --config-file pyproject.toml --namespace-packages --explicit-package-bases
rt2=$?

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) ]]; then
  exit 0
else
  exit 255
fi
