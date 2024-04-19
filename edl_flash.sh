DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export EDL=$DIR/edl/edl
echo $EDL

$EDL w $1 $2 --memory=ufs
