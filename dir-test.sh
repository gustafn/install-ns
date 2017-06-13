S=$(dirname "$0")
echo "S $S"
SCRIPTPATH=$(cd $(dirname "$0") ; pwd -P )
echo "SCRIPPATH ${SCRIPTPATH}"
SCRIPT=`realpath $0`
echo "SCRIPT ${SCRIPT}"
S2="$(realpath .)"
echo "S2 $S2"
