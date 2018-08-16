#!/bin/bash

# TODO:Add more github repos to this array!
# declare -a github_projects$()

config=./settings.txt

# THIS SCRIPT
prog=${0##*/}

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
  git clone --depth=1 "$1" "$2"
}


git_remote_update(){
  git --git-dir="$1"/.git \
    --work-tree="$1" remote update
}

download_github_release(){
  url=$(echo $1 | sed 's/"//g')
  project="$2"

  filename=$(basename "$url")
  tag=$(echo $url |sed s/$filename//g | tr '/' ' '|awk '{print $NF}')
  if [ ! -f "$release"/"$project"/"$tag"/"$filename" ]; then
    wget -q --show-progress "$url" -P "$release"/"$project"/"$tag"
  else
    echo "File exists! Skipping! [ ./$release/$project/$filename ]"
  fi
}


# Main project commands
clone_repos(){
  total=${#all_git_repos[*]}
  printf "${#all_git_repos[*]} github projects listed ..\n"
  for (( n = 0; n < total; n++ ))
  do
    print_line
    echo debug ${all_git_repos[n]}
    echo "Testing for [ `echo $n+1|bc`/$total ] - ${all_git_repos[n]}"
    url=${all_git_repos[n]}
    last=${url##*/}
    bare=${last%%.git}
    if [ -d "$source"/"$bare" ]; then
        echo "Info: [$source/$bare] already present -- Action: skipping"
      else
        git_shallow_clone "$url" "$source"/"$bare"
    fi
  done
}


destructive_update(){
  echo "This is a destructive command!"
  here=$(pwd);find . -iname '*.git' -type d |while read -r foo;do cd $foo/..;git remote -v;cd $here;done
}


update_listed_git_repos(){
  total=${#all_git_repos[*]}
  printf "${#all_git_repos[*]} github projects . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    echo "Updating project [ `echo $n+1|bc`/$total ] - ${all_git_repos[n]}"
    url=${all_git_repos[n]}
    last=${url##*/}
    bare=${last%%.git}
    if [ -d "$source"/"$bare" ]; then
      git --git-dir="$source"/"$bare"/.git --work-tree="$source"/"$bare" pull --rebase origin master
    else
      echo "Project ${all_git_repos[n]} not present. Cloning now..."
      git_shallow_clone "$url" "$source"/"$bare"
      echo "Project ${all_git_repos[n]} cloned!"
    fi
    echo
  done
}


show_last_repo_commits(){
  total=${#all_git_repos[*]}
  printf "Looking for ${#all_git_repos[*]} github projects . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${all_git_repos[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    if [ -d "$source"/"$bare" ]; then
      git --git-dir="$source"/"$bare"/.git \
        --work-tree="$source"/"$bare" \
        log -1 \
        --pretty=format:"Commit: %Cred%h%nLast commit was %ar: [ %Cblue%ad ]%nMessage: [%Cgreen%s]%nAuthor: %Cred%aN %Cblue<%ae>"
      git_remote_update "$source"/"$bare" > /dev/null 2>&1
      echo -n "Project branch status: "
      git --git-dir="$source"/"$bare"/.git \
        --work-tree="$source"/"$bare" status
      else
        echo "Issue! [${source}/${bare}] does not exist in local path [Use ${prog} -c to add]"
    fi
  done
}


show_official_releases(){
  # Permutation of this curl command
  # curl -H "Authorization: token $GITHUB_TOKEN" -s https://api.github.com/repos/<githubuser>/<project>/releases/latest | grep browser_download_url| awk '{print $2}'
  total=${#github_projects[*]}
  printf "Looking for ${#github_projects[*]} release candidates . . .\n"
  for (( n = 1; n < total; n++ ))
  do
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    # convert remote origin to release URI
    release_api_tag=$( git --git-dir="$source"/"$bare"/.git \
          --work-tree="$source"/"$bare" \
          remote get-url --all origin|\
          head -1 |\
          sed 's/github.com/api.github.com\/repos/g')

    list=$(mktemp)

    # Use curl to fetch latest release if available
    smarter_curl "$release_api_tag"/releases/latest |\
      grep browser_download_url|\
      awk '{print $2}' >> $list

    # Print list out
    cat $list

    # Download these releases!
    for files in $( cat $list )
    do
      download_github_release "$files" "$bare"/official-releases
    done
  done
}


show_bleeding_edge_releases(){
  # TODO: Use jq to parse for anything not marked as release - this prevents duplicate downloads
  # Permutation of this curl command
  # curl -H "Authorization: token $GITHUB_TOKEN" -s https://api.github.com/repos/<githubuser>/<project>/releases|jq '.[0]' -r |grep browser_download_url|awk '{print $NF}'

  # State all repos
  printf "[${#all_git_repos[*]}] repos total. "
  printf "[${#github_projects[*]}] github projects. "
  printf "[${#bitbucket_projects[*]}] bitbucket projects.\n\n"
  printf "Looking for any most recently posted pre-release download. . .\n"

  # Start with github
  total=${#github_projects[*]}
  printf "Step: github.com - [${#github_projects[*]}] repo(s) . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${github_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    # convert remote origin to release URI
    release_api_tag=$( git --git-dir="$source"/"$bare"/.git \
          --work-tree="$source"/"$bare" \
          remote get-url --all origin|\
          head -1 |\
          sed 's/github.com/api.github.com\/repos/g')

    list=$(mktemp)

    # Use curl to fetch latest release if available
    smarter_curl "$release_api_tag"/releases |\
      jq '.[0]' -r |\
      grep browser_download_url|\
      awk '{print $NF}' >> $list

    # Print list out
    cat $list

    # Download these releases!
    for files in $( cat $list )
    do
      download_github_release "$files" "$bare"/all-releases
    done
  done

  # Start with github
  total=${#bitbucket_projects[*]}
  echo
  printf "Step: bitbucket.org - [${#bitbucket_projects[*]}] repo(s) . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${bitbucket_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    print_line
    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    # convert remote origin to release URI
    release_api_tag=$( echo $url |\
        sed 's/bitbucket.org/api.bitbucket.org\/2.0\/repositories/g')

    list=$(mktemp)

    # Use curl to fetch latest release if available
    curl -s -L "$release_api_tag"/downloads |\
      jq '.values[].links[].href' >> $list

    # Print list out
    cat $list

    # Download these releases!
    for files in $( cat $list )
    do
      download_github_release "$files" "$bare"/all-releases
    done
  done
}


setup_github_creds(){
  # TODO: bash dependencies tes for jq, curl, wget, git-core
  if [ -f "$HOME/.netrc" ]; then
    export GITHUB_TOKEN=$(grep github.com "$HOME"/.netrc|awk '{print $NF}')
  else
    echo "No github token found for user, calls to github will be unauthenticated, which may be rate limited"
  fi
}


smarter_curl(){
  if [ -n "$GITHUB_TOKEN" ]; then
    curl -H "Authorization: token $GITHUB_TOKEN" -s "$1"
  else
    curl -s "$1"
  fi
}


config_sanity(){
  #TODO: Fix section parsing
  if [ -z "$source" ]; then
    "Error: No source folder set! Set source path in $config under section [source]"
    exit
  fi

  if [ -z "$release" ]; then
    "Error: No source folder set! Set release path in $config under section [release]"
    exit
  fi
}


# Begin! main()
# Test for passed parameters, if none, print help text
if [ "$#" -lt 1 ]; then
    echo $prog": no arguments provided"
    echo "This tool clones the following github projects: "
    echo "[ ${github_projects[*]##*/} ]"
    echo "Try '"$prog" -h' for more information."
fi

setup_github_creds

# Parse config file
section=github
IFS=$'\r\n' GLOBIGNORE='*' command eval  'github_projects=($(awk "/\[$section]/,/^$/" $config | sed -e '/^$/d' -e "/\[$section\]/d"))'

section=bitbucket
IFS=$'\r\n' GLOBIGNORE='*' command eval  'bitbucket_projects=($(awk "/\[$section]/,/^$/" $config | sed -e '/^$/d' -e "/\[$section\]/d"))'

# Merge all arrays here!
all_git_repos=( "${github_projects[@]}" "${bitbucket_projects[@]}" )

section=release
release=$(awk "/\[$section]/,/^$/" $config | sed -e '/^$/d'| tail -1)

section=source
source=$(awk "/\[$section]/,/^$/" $config | sed -e '/^$/d'| tail -1)

config_sanity

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
