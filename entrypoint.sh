#!/bin/bash

# Makes and Creates a debian package
# This script works in a local docker container or with it's Github action.yml
# ./build directory is cleaned every time
# the version generated is only for development builds currently

#see action.yml for inputs
NONE="None"
DEBIAN_DIR=debian
version=${1:-$NONE} # the version of the generated package
build_number=${2:-$NONE}
pull_request_number=${3:-$NONE}
branch=${4:-$NONE}



# extract the package name from the control file
package_name_from_control(){
    #get the project name from the control file
    package_line=$(cat debian/control | grep Package)
    echo "$package_line" | awk -F': ' '{print $2}'
}

# replaces / with - so feature/BB-182 = feature-BB-182 for version compatibility
append_branch_version(){
    if [[ $branch != $NONE ]]; then
        echo ".$(echo "$branch" | tr / -)"
    fi
}

# uses or makes version based on caascading set of rules based on what is provided
# if
version_guaranteed(){
    
    if [[ $version != $NONE ]]; then
        # use version as provided
        v=$version
        elif [[ $pull_request_number != $NONE ]]; then
        # pr as the major is good for consistency and identity
        # possibilities:
        # {pr#}
        # {pr#}.{branch}
        # {pr#}.{build#}
        # {pr#}.{branch}.{build#}
        v=$pull_request_number$(append_branch_version)
        if [[ $build_number != $NONE ]]; then
            v="$v.$build_number"
        fi
        elif [[ $build_number != $NONE ]]; then
        # build number is fine as the major and is good for identify (once github provides it)
        # branch provides consistency across builds
        # {build#}
        # {build#}.{branch}
        v=$build_number$(append_branch_version)
    else
        # nothing provided.  use date
        # {timestamp}
        # {timestamp}.{branch}
        v=$(date +%Y%m%d%H%M%S )$(append_branch_version)
    fi
    
    echo $v
}
# ========= MAIN

set -e # fail on error

# the directory where the artifact should be copied so other actions can access
# see also https://medium.com/@fonseka.live/sharing-data-in-github-actions-a9841a9a6f42
staging_dir="/github/home"
workspace="/github/workspace"

# the git root is always mapped to the docker's /root
mkdir -p $workspace
mkdir -p $staging_dir
cd $workspace

source /opt/ros/kinetic/setup.bash

if [[ ! -d "$DEBIAN_DIR" ]]; then
    echo "$DEBIAN_DIR must exist with rules (executable), "
    exit 1
fi

package_name=$(package_name_from_control)
#TODO: get release notes from github and add them to the changelog
control_version_line="$package_name ($(version_guaranteed)) unstable; urgency=medium"
echo $control_version_line > $DEBIAN_DIR/changelog


# clean the debian and build directories and will validate necessary files
fakeroot debian/rules clean #ensures no residue
fakeroot debian/rules binary #performs the package

artifact_filename=$(ls .. | grep .deb | tail -1) #the package is generated in base directory
artifact_path="$staging_dir/$artifact_filename"

mv ../$artifact_filename $artifact_path

#show the details of the file FYI and to validate existence
ls -lh $artifact_path

echo ::set-output name=artifact-path::$artifact_path  #reference available to other actions
