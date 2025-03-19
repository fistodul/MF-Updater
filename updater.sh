#!/bin/sh

url='https://mf.nofisto.com/fast_download'

skipFiles=(
  #'Sounds/Announcer.uax'
  #'Sounds/RagePlayerVoice.uax'
  'System/Core.int'
  'System/D3DDrv.int'
  'System/Editor.int'
  'System/Engine.int'
  'System/Engine.u'
  'System/Galaxy.int'
  'System/IpDrv.int'
  'System/IpServer.int'
  'System/License.int'
  'System/Manifest.int'
  'System/MobileForcesEd.int'
  'System/MobileForces.int'
  'System/RageBrowser.int'
  'System/RageGame.int'
  'System/RageGfx.int'
  'System/Rage.int'
  'System/RageMenu.int'
  'System/RageWeapons.int'
  'System/Setup.int'
  'System/Startup.int'
  'System/UBrowser.int'
  'System/Window.int'
  'System/WinDrv.int'
  #'Textures/rage_warehouse.utx'
  'Textures/MobileForceFonts.utx'
)

# function arguments: $1 is the file to check the sum of
sha_cmd () {
  # executes the injected command or defaults to shasum
  eval "${SHA_CMD:-shasum -a 512 -c -s $1}"
}

# function arguments: $1 is the url and $2 the file to download
wget_cmd () {
  # executes the injected command or defaults to curl with -o
  eval "${WGET_CMD:-curl -sf \'$1/$2\' -o $2}"
}

# function arguments: $1 is the program to start
wine_cmd () {
  # executes the injected command or defaults to wine
  eval "${WINE_CMD:-wine $1}" 2> /dev/null
}

checkIfFilesExist() {
  MAPS='Maps';
  [ -d "$MAPS" ] || MAPS='maps';

  for folder in $MAPS Music Physics Sounds System Textures; do
    if ! [ -d "../$folder" ]; then
      echo "Couldn't find $folder in parallel folders, can't continue"
      read -n 1
      exit 1
    fi
  done

  if ! [ -f '../System/UCC.exe' ]; then
    echo Couldn't find UCC.exe in System folder, can't continue
    read -n 1
    exit 1
  fi
}

downloadShasums() {
  echo Trying to download sha512.txt
  wget_cmd $url sha512.txt

  if ! [ -f sha512.txt ]; then
    echo Failed to download sha512.txt or recreate it
    read -n 1
    exit 1
  fi
}

setInfo() {
  if [[ -z $remoteHash ]]; then
    remoteHash=$word
    return 1

  elif [[ -z $filename ]]; then
    filename=$(echo $word | sed 's/.*\///')
    ext=$(echo $filename | sed 's/.*\.//')
  fi
}

clearInfo() {
  unset remoteHash
  unset filename
}

recognizeExtension() {
  case $ext in
    umf | umx | uax | u | utx)
      textFile=0;;
    COL | hnd2 | int)
      textFile=1;;
    *)
      echo "Unknown extension $ext, skipping"
      textFile=-1
      ;;
  esac

  return $textFile
}

setLocalHash() {
  if [[ -a "../${folder}/${filename}" ]]; then
    localHash=$(sha256sum "../${folder}/${filename}" | sed 's/ .*//')
  elif [[ ! -z $localHash ]]; then
    unset localHash
  fi
}

checkHashes() {
  if [[ $localHash == $remoteHash ]]; then
    echo "$filename is up to date"
    clearInfo
    return 0

  elif [[ -z $localHash ]]; then
    echo "$filename is missing"
  else
    echo "$filename is mismatching"
    echo "Local file hash:  $localHash"
    echo "Remote file hash: $remoteHash"
  fi

  return 1
}

getFile() {
  if [[ $filename == 'Engine.u' || $filename == 'RageWeapons.u' ]]; then
    echo "$filename is assumed to be indecompressible"
    echo "Downloading $filename from the server"
    wget -q -c "https://mf.nofisto.com/fast_download/$filename" -O "$filename"
    mv "$filename" ../System
  elif (( ! $textFile )); then
    echo "Downloading ${filename}.uz from the server"
    wget -q -c "https://mf.nofisto.com/fast_download/${filename}.uz" -O "${filename}.uz"
    echo "Decompressing ${filename}.uz"
    cd ../System
    wine UCC decompress "../Updater/${filename}.uz" 2> /dev/null
    cd ../Updater

    if [[ $folder != 'System' ]]; then
      mv "../System/$filename" "../$folder"
    fi

    rm ${filename}.uz;
  else
    echo "Downloading $filename from the server"
    wget -q -c "https://mf.nofisto.com/fast_download/$filename" -O "$filename"
    mv "$filename" "../$folder"
  fi
}

checkIfFilesExist
downloadShasums

while read word; do
  setInfo

  if (( $? == 1 )); then
    continue
  fi

  recognizeExtension
  setLocalHash
  checkHashes

  if (( $? == 0 )); then
    continue
  fi

  getFile
  clearInfo
done < sha512.txt

echo Update finished
read -n 1
