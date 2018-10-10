#!/bin/bash

# :TODO Add depth option to set git clone depth
# :TODO Add long format options (eg: --beta/-b)
# :TODO Add force replace for download options (release/beta) - ie: replace existing download files (skip existing)
# :TODO Add option to pass in config filename (currently hardcoded to `settings.txt`)
# :TODO Add option to target single git projects for all commands

config=./settings.txt

# THIS SCRIPT
prog=${0##*/}


print_usage()
{
    echo "usage: "$prog" [-c clone useful git repos] [-h help] [-l list repos in settings.txt]"
    echo -e "\t\t[-b show bleeding edge release downloads] [-r show official release downloads]"
    echo -e "\t\t[-s show current commit status] [-u update all project repositories]"
    exit;
}


print_line(){
  printf '.%.0s' {1..80}
  echo
}


print_download_list()
{
  list="$1"
  message="$2"

  echo "[`wc -l < $list`] - "$message" file(s) listed"
  cat "$list" | awk '{print "-> " $NF}'
}


# Git commands
git_shallow_clone(){
  git clone --depth=1 "$1" "$2"
}


git_remote_update(){
  git --git-dir="$1"/.git \
    --work-tree="$1" remote update
}


# Main project commands
clone_repos(){
  total=${#git_projects[*]}
  printf "${#git_projects[*]} github projects listed ..\n"
  for (( n = 0; n < total; n++ ))
  do
    print_line
    echo "Testing for [ `echo $n+1|bc`/$total ] - ${git_projects[n]}"
    url=${git_projects[n]}
    last=${url##*/}
    bare=${last%%.git}

    # Hack to get username
    git_user=$(echo "${url//// }"| awk '{print $3}')
    git_path=$(echo "$source"/"$git_user"/"$bare")

    if [ -d "$git_path" ]; then
        echo "Info: [$git_path] already present -- Action: skipping"
      else
        git_shallow_clone "$url"  "$git_path"
    fi
  done
}


update_listed_git_repos(){

  total=${#git_projects[*]}
  printf "${#git_projects[*]} github projects . . .\n"

  for (( n = 0; n < total; n++ ))
  do
    echo "Updating project [ `echo $n+1|bc`/$total ] - ${git_projects[n]}"
    url=${git_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    git_user=$(echo "${url//// }"| awk '{print $3}')
    git_path=$(echo "$source"/"$git_user"/"$bare")

    if [ -d "$git_path" ]; then
      git --git-dir="$git_path"/.git \
        --work-tree="$git_path" pull --rebase origin master
    else
      echo "Project ${git_projects[n]} not present. Cloning now..."
      git_shallow_clone "$url" "$git_path"
      echo "Project ${git_projects[n]} cloned!"
    fi
    echo
  done
}


show_last_repo_commits(){
  total=${#git_projects[*]}
  printf "Looking for ${#git_projects[*]} github projects . . .\n"

  for (( n = 0; n < total; n++ ))
  do
    url=${git_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    git_user=$(echo "${url//// }"| awk '{print $3}')
    git_path=$(echo "$source"/"$git_user"/"$bare")

    print_line

    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} .."
    if [ -d "$git_path" ]; then
      git --git-dir="$git_path"/.git \
        --work-tree="$git_path" \
        log -1 \
        --pretty=format:"Commit: %Cred%h%nLast commit was %ar: [ %Cblue%ad ]%nMessage: [%Cgreen%s]%nAuthor: %Cred%aN %Cblue<%ae>"
      git_remote_update "$git_path" > /dev/null 2>&1
      echo -n "Project branch status: "
      git --git-dir="$git_path"/.git \
        --work-tree="$git_path" status
      else
        echo "Issue! [${git_path}] does not exist in local path [Use ${prog} -c to add]"
    fi
  done
}


download_official_releases(){
  total=${#git_projects[*]}
  printf "Looking for ${#git_projects[*]} release candidates . . .\n"
  for (( n = 0; n < total; n++ ))
  do
    url=${git_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    git_user=$(echo "${url//// }"| awk '{print $3}')

    print_line

    echo "Checking [ `echo $n+1|bc`/$total ]- ${bare} (${git_user}).."

    # ------- logic section for processing github uri's ------- #
    if [[ "$url" = *"github"* ]]; then
      # convert remote origin to release URI
      release_api_tag=$( echo "$url" |sed 's/github.com/api.github.com\/repos/g')

      list=$(mktemp)

      # Use curl to fetch latest release if available
      # curl -H "Authorization: token $GITHUB_TOKEN" -s "$release_api_tag"/releases/latest | jq -r '.prerelease, .assets[].browser_download_url'
      github_curl "$release_api_tag"/releases/latest | \
        jq -r '(.prerelease| tostring)? + " " + (.created_at)? +
          " " + (.assets[].browser_download_url| tostring)?' \
          >> $list

      test_pre_release_status=$(cat $list |awk '/^false*/')

      # Note: The github releases api endpoint returns a keypair 'prerelease: "false"'
      # to denote whether something is flagged as release or prerelease.
      # Here we are testing for the false flag to tell is this is not prerelease
      if [  -n "$test_pre_release_status"  ]; then
        print_download_list $list "release candidate"

        # Download these releases!
        cat $list | while read status uploaded_tag files
        do
          # Cheap hack to shorten the .created_at to folder friendly name -
          # `CCYY-MM-DD` from format: `2018-08-06T05:10:33Z`
          created_on=$(echo $uploaded_tag | cut -d 'T' -f 1)

          # usage: download_github_release <URL> <git_user>/<project_name>/<release_folder_name> <created_on_tag>
          download_github_release "$files" "$git_user"/"$bare"/release "$created_on"
        done
      else
        echo "Info: No release downloads found"
      fi

    # ------- logical loop for processing bitbucket uri's ------- #
    elif [[ "$url" = *"bitbucket"* ]]; then

    # Bitbucket doesn't follow the github [release/pre-release] convention
    # We're using all-releases as our default
    download_bitbucket_release "$url" "$git_user"/"$bare"/release

    elif [[ "$url" = *"gitlab"* ]]; then
      echo "gitlab"
    fi

  done
}


download_bleeding_edge_releases(){
  # Permutation of this curl command
  # curl -H "Authorization: token $GITHUB_TOKEN" -s https://api.github.com/repos/<githubuser>/<project>/releases|jq '.[0]' -r |grep browser_download_url|awk '{print $NF}'

  # State all repos
  printf "[${#git_projects[*]}] repos total. "
  printf "[`printf "%s\n" "${git_projects[@]}"|grep -c github`] github projects. "
  printf "[`printf "%s\n" "${git_projects[@]}"|grep -c bitbucket`] bitbucket projects.\n\n"
  printf "Looking for any most recently posted pre-release download. . .\n"

  total=${#git_projects[*]}
  printf "Examining - [${#git_projects[*]}] repo(s) . . .\n"

  for (( n = 0; n < total; n++ ))
  do
    url=${git_projects[n]}
    last=${url##*/}
    bare=${last%%.git}
    git_user=$(echo "${url//// }"| awk '{print $3}')

    print_line

    echo "Checking [ `echo $n+1|bc`/$total ] - ${bare} (${git_user}).."

    list=$(mktemp)

    if [[ "$url" = *"github"* ]]; then
      # convert remote origin to release URI
      release_api_tag=$( echo "$url" |sed 's/github.com/api.github.com\/repos/g')

      # Use curl to fetch pre-release if available
      github_curl "$release_api_tag"/releases | jq -r \
        '.[0] | (.prerelease|tostring)? + " " + (.created_at)? +
          " " +(.assets[].browser_download_url|tostring)?' \
          >> $list

      # Note: The github releases api endpoint returns a keypair 'prerelease: "true"'
      # to denote whether something is flagged as release or prerelease.
      # Here we are testing for the `true` value to tell is this is a pre-release
      test_pre_release_status=$(cat $list |awk '/^true*/')

      if [  -n "$test_pre_release_status"  ]; then
        print_download_list $list "pre-release candidate"

        # Download these releases!
        cat $list | while read status uploaded_tag files
        do
          # Cheap hack to shorten the .created_at to folder friendly name -
          # `CCYY-MM-DD` from format: `2018-08-06T05:10:33Z`
          created_on=$(echo $uploaded_tag | cut -d 'T' -f 1)

          # download_github_release <URL> <git_user>/<project_name>/<release_folder_name> <created_on_tag>
          download_github_release "$files" "$git_user"/"$bare"/beta "$created_on"
        done
      else
        echo "Info: No pre-release (bleeding edge) downloads found"
      fi

    # ------- section for processing bitbucket uri's ------- #
    elif [[ "$url" = *"bitbucket"* ]]; then
      # convert remote origin to release URI
      release_api_tag=$( echo $url |\
        sed 's/bitbucket.org/api.bitbucket.org\/2.0\/repositories/g')

      # Bitbucket doesn't follow the github [release/pre-release] convention
      # We're using all-releases as our default
      download_bitbucket_release "$url" "$git_user"/"$bare"/release

    elif [[ "$url" = *"gitlab"* ]]; then
      echo "gitlab"
    fi

  done
}


download_github_release(){
  url=$(echo $1 | sed 's/"//g')
  project="$2"
  created_on="$3"

  filename=$(basename "$url")

  # Hack to remove filename from url string and grab preceding github tag
  tag=$(echo $url |sed s/$filename//g | tr '/' ' '|awk '{print $NF}')

  path=$( echo "$release"/"$project"/"$tag"_"$created_on")

  # Test to see file exists before download
  if [ ! -f "$path"/"$filename" ]; then
    wget -q --show-progress "$url" -P "$path"
  else
    echo "Target exists! Skipping! [ ./$path/$filename ]"
  fi
}


download_bitbucket_release(){
  url=$(echo $1 | sed 's/"//g')
  project="$2"

  # convert remote origin to release URI
  release_api_tag=$( echo $url |\
    sed 's/bitbucket.org/api.bitbucket.org\/2.0\/repositories/g')

   list=$(mktemp)

   # Use curl to fetch latest release if available
  curl -s -L "$release_api_tag"/downloads|\
    jq -r '.values[0]? | (.created_on?|tostring) + " " + (.links[].href?|tostring)' \
      >> $list

  # Test to see our list has been populated by our curl call
  # If this has something in it, act on the list
  if [ -s $list ]; then
    print_download_list $list "bitbucket.org"

    # Download these releases!
    cat $list | while read uploaded_tag files
    do
      # Cheap hack to shorten the .created_on to folder friendly name -
      # `CCYY-MM-DD` from format: `2018-08-19T21:57:47.108457+00:00`
      created_on=$(echo $uploaded_tag | cut -d 'T' -f 1)

      # Remove some basic HTML formatting so we can test for a filename
      # existing in our path by replaceing '%20' with a space char
      filename=$(basename "$files"| sed 's/\%20/\ /g')
      path=$(echo "$release"/"$project"/"$created_on")

      # Test to see whether or not file exists before proceeding
      if [ ! -f "$path"/"$filename" ]; then
        wget_with_useragent "$files" "$path"

        else
          echo "Target exists! Skipping! [ ./"$path"/"$filename" ]"
      fi
    done

    else
      # '$list' is empty, nothing to download
      echo "Info: No recent releases for download listed for this project"
  fi
}


setup_github_creds(){
  if [ -f "$HOME/.netrc" ]; then
    export GITHUB_TOKEN=$(grep github.com "$HOME"/.netrc|awk '{print $NF}')
  else
    echo "No github token found for user, calls to github will be " \
      "unauthenticated, which may be rate limited"
  fi
}


github_curl(){
  if [ -n "$GITHUB_TOKEN" ]; then
    curl -H "Authorization: token $GITHUB_TOKEN" -s "$1"
  else
    curl -s "$1"
  fi
}


wget_with_useragent(){
  files="$1"
  path="$2"

  wget -q \
    --user-agent="Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0" \
    --show-progress "$files" \
    --directory-prefix "$path"
}


config_sanity(){
  # TODO: bash dependencies tes for jq, curl, wget, git-core
  if [ -z "$source" ]; then
    "Error: No source folder set! Set source path in $config under section [source]"
    exit
  fi

  if [ -z "$release" ]; then
    "Error: No source folder set! Set release path in $config under section [release]"
    exit
  fi
}


print_array(){
  arr=("${!1}")
  echo "[${#arr[@]}] $2"
  for i in ${arr[@]}
  do
    printf "    %s\n" $i
  done
}


list_repos(){
  printf "Listing remote git repositories from [$config]\n"
  print_line
  print_array "git_projects[@]" "hosted git projects"
  print_line
  printf "[`printf "%s\n" "${git_projects[@]}"|grep -c github`] - github.com projects\n"
  printf "[`printf "%s\n" "${git_projects[@]}"|grep -c bitbucket`] - bitbucket.org projects\n"
  printf "[`printf "%s\n" "${git_projects[@]}"|grep -c gitlab`] - gitlab.com projects\n"
}


# Begin! main()
# Test for passed parameters, if none, print help text
if [ "$#" -lt 1 ]; then
    echo $prog": no arguments provided"
    echo "This tool clones github projects from [$config]: "
    echo "Try '"$prog" -h' for more information."
fi

setup_github_creds

# Parse config file
section=git
git_projects=($(awk "/\[$section]/,/^$/" $config | sed -e '/^$/d' -e "/\[$section\]/d" -e '/^#/d'))

release=$( grep '^release' $config |cut -d '=' -f 2 )
source=$( grep '^source' $config |cut -d '=' -f 2 )

config_sanity

# Main processing loop
while getopts :bchlrsu option; do
  case "${option}" in
    c)
        clone_repos
        exit;;
    b)
        download_bleeding_edge_releases
        exit;;
    h)
        print_usage
        exit;;
    l)
        list_repos
        exit;;
    r)
        download_official_releases
        exit;;
    s)
        show_last_repo_commits
        exit;;
    u)
        update_listed_git_repos
        exit;;
    *)
        # Evaluate passed parameters, if none display DNS and exit with help statement
        echo $prog: illegal option -- ${OPTARG}
        print_usage
  esac
done
