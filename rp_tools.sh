#!/bin/bash

# TODO:Add more github repos to this array!
declare -a github_projects=( \
  https://github.com/SmokeMonsterPacks/EverDrive-Packs-Lists-Database \
  https://github.com/RedGuyyyy/sd2snes \
  https://github.com/JakobAir/ViperGC \
  https://github.com/SmokeMonsterPacks/Super-NT-Jailbreak \
  https://github.com/blastrock/pkgj \
  https://github.com/OtherCrashOverride/go-play \
  https://github.com/OtherCrashOverride/odroid-go-firmware \
  https://github.com/OtherCrashOverride/doom-odroid-go \
)

# THIS SCRIPT
prog=${0##*/}

# TODO: bash dependencies tes for jq, curl, wget, git-core

print_line(){
  printf '.%.0s' {1..80}
  echo
}

print_usage()
{
    echo "usage: "$prog" [-c clone useful git repos] [-d destructive git rebase] [-h help]"
    echo -e "\t\t[-b show bleeding edge release downloads] [-r show official release downloads]"
    echo -e "\t\t[-s show current commit status] [-u update all project repositories]"
    exit;
}


# Git commands
git_shallow_clone(){
  git clone --depth=1 "$1"
}


git_remote_update(){
  git --git-dir="$1"/.git \
    --work-tree="$1" remote update
}


# Main project commands
clone_repos(){
  total=${#github_projects[*]}
  printf "${#github_projects[*]} github projects listed ..\n"
  for (( n = 0; n < total; n++ ))
  do
    print_line
    echo "Testing for [ `echo $n+1|bc`/$total ] - ${github_projects[n]}"
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    if [ -d "$bare" ]; then
        echo "Info: [$bare] already present -- Action: skipping"
      else
        git_shallow_clone "$url"
    fi
  done
}


destructive_update(){
  echo "This is a destructive command!"
  here=$(pwd);find . -iname '*.git' -type d |while read -r foo;do cd $foo/..;git remote -v;cd $here;done
}


update_listed_git_repos(){
  total=${#github_projects[*]}
  printf "${#github_projects[*]} github projects . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    echo "Updating project [ `echo $n+1|bc`/$total ] - ${github_projects[n]}"
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    if [ -d "$bare" ]; then
      git --git-dir="$bare"/.git --work-tree="$bare" pull --rebase origin master
    else
      echo "Project ${github_projects[n]} not present. Cloning now..."
      git_shallow_clone "$url"
      echo "Project ${github_projects[n]} cloned!"
    fi
    echo
  done
}


show_last_repo_commits(){
  total=${#github_projects[*]}
  printf "Looking for ${#github_projects[*]} github projects . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    if [ -d "$bare" ]; then
      git --git-dir="$bare"/.git \
        --work-tree="$bare" \
        log -1 \
        --pretty=format:"Commit: %Cred%h%nLast commit was %ar: [ %Cblue%ad ]%nMessage: [%Cgreen%s]%nAuthor: %Cred%aN %Cblue<%ae>"
      git_remote_update "$bare" > /dev/null 2>&1
      echo -n "Project branch status: "
      git --git-dir="$bare"/.git \
        --work-tree="$bare" status
      else
        echo "Issue! [${bare}] does not exist in local path [Use ${prog} -c to add]"
    fi
  done
}


show_official_releases(){
  # Permutation of this curl command
  # curl -H "Authorization: token $GITHUB_TOKEN" -s https://api.github.com/repos/<githubuser>/<project>/releases/latest | grep browser_download_url| awk '{print $2}'
  total=${#github_projects[*]}
  printf "Looking for ${#github_projects[*]} release candidates . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    # convert remote origin to release URI
    release_api_tag=$( git --git-dir="$bare"/.git \
          --work-tree="$bare" \
          remote get-url --all origin|\
          head -1 |\
          sed 's/github.com/api.github.com\/repos/g')
    # Use curl to fetch latest release if available
    curl -s "$release_api_tag"/releases/latest |\
      grep browser_download_url|\
      awk '{print $2}'
  done
}

show_bleeding_edge_releases(){
  # Permutation of this curl command
  # curl -H "Authorization: token $GITHUB_TOKEN" -s https://api.github.com/repos/<githubuser>/<project>/releases|jq '.[0]' -r |grep browser_download_url|awk '{print $NF}'
  total=${#github_projects[*]}
  printf "Looking for ${#github_projects[*]} pre-release posts . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    # convert remote origin to release URI
    release_api_tag=$( git --git-dir="$bare"/.git \
          --work-tree="$bare" \
          remote get-url --all origin|\
          head -1 |\
          sed 's/github.com/api.github.com\/repos/g')
    # Use curl to fetch latest release if available
    curl -s "$release_api_tag"/releases |\
      jq '.[0]' -r |\
      grep browser_download_url|\
      awk '{print $NF}'
  done
}


# Test for passed parameters, if none, print help text
if [ "$#" -lt 1 ]; then
    echo $prog": no arguments provided"
    echo "This tool clones the following github projects: "
    echo "[ ${github_projects[*]##*/} ]"
    echo "Try '"$prog" -h' for more information."
fi

# Main processing loop
while getopts :bcdhrsu option; do
  case "${option}" in
    c)
        c=${OPTARG}
        echo "Cloning all specified project repos into current directory"
        clone_repos
        exit;;
    b)
        b=${OPTARG}
        echo "Checking for bleeding edge releases"
        show_bleeding_edge_releases
        exit;;
    d)
        a=${OPTARG}
        echo "Destructive! Finds all repos in this path and updates to latest master branch commit"
        echo "Destructive assumes no changes exist locally for repositories"
        destructive_update
        exit;;
    h)
        h=${OPTARG}
        print_usage
        exit;;
    r)
        r=${OPTARG}
        echo "Show official releases on github projects"
        show_official_releases
        exit;;
    s)
        u=${OPTARG}
        echo "Show last commit entry for all repos"
        show_last_repo_commits
        exit;;
    u)
        u=${OPTARG}
        update_listed_git_repos
        exit;;

    *)
        # Evaluate passed parameters, if none display DNS and exit with help statement
        echo $prog: illegal option -- ${OPTARG}
        print_usage
        ;;
  esac
done
