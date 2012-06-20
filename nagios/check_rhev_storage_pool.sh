#!/bin/sh
# Nagios check to verify the status of the storage pools
# from the hypervisor SPM. This is compatible with RHEV 2.2
# and SAN storage pools
# Author: Marek Mahut 

# OK                                  (exit code 0)
# WARNING - vg1/lv0/92%  vg2/lv1/94%  (exit code 1)
# CRITICAL - vg0/lv0/97%  vg1/lv0/92% (exit code 2)



# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

print_usage() {
    echo "Usage: $PROGNAME [-h|-V] | -w nnn -c nnn"; echo ""
    echo "  -h, --help"; echo "          print the help message and exit"
    echo "  -V, --version"; echo "          print version and exit"
    echo "  -w nnn, --warning=nnn"; echo "          warning threshold for ammount of space used"
    echo "  -c nnn, --critical=nnn"; echo "          critical threshold for ammount of space used"
}

print_help() {
    echo ""
    echo "Plugin for Nagios to check used space on VG for RHEV"
    echo ""
    print_usage
    echo ""
}

# Make sure the correct number of command line
# arguments have been supplied

if [[ ! `echo "$*" |grep -E "(-[hVwc]\>|--(help|version|warning|critical)=)"` ]]; then
    print_usage
    exit $STATE_UNKNOWN
fi

# Grab the command line arguments

thresh_warn=""
thresh_crit=""
exitstatus=$STATE_WARNING #default
while test -n "$1"; do
    case "$1" in
        --help)
            print_help
            exit $STATE_OK
            ;;
        -h)
            print_help
            exit $STATE_OK
            ;;
        --version)
            print_version
            exit $STATE_OK
            ;;
        -V)
            print_version
            exit $STATE_OK
            ;;
        --warning=*)
            thresh_warn=`echo $1 | awk -F = '{print $2}'`
            if [[ `expr match "$thresh_warn" '\([0-9]*\)'` != $thresh_warn ]] || [ -z $thresh_warn ]; then
                echo "Warning value must be a number greater than zero"
                exit $STATE_UNKNOWN
            fi
            ;;
        -w)
            thresh_warn=$2
            if [[ `expr match "$thresh_warn" '\([0-9]*\)'` != $thresh_warn ]] || [ -z $thresh_warn ]; then
                echo "Warning value must be a number greater than zero"
                exit $STATE_UNKNOWN
            fi
            shift
            ;;
        --critical=*)
            thresh_crit=`echo $1 | awk -F = '{print $2}'`
            if [[ `expr match "$thresh_crit" '\([0-9]*\)'` != $thresh_crit ]] || [ -z $thresh_crit ]; then
                echo "Critical value must be a number greater than zero"
                exit $STATE_UNKNOWN
            fi
            ;;
        -c)
            thresh_crit=$2
            if [[ `expr match "$thresh_crit" '\([0-9]*\)'` != $thresh_crit ]] || [ -z $thresh_crit ]; then
                echo "Critical value must be a number greater than zero"
                exit $STATE_UNKNOWN
            fi
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done


# Verify if we're the SPM
if [ `ps aux | grep -c spmprotect.sh` -lt 2 ]; then
    echo "OK - This node is not a SPM"
    exit $STATE_OK
fi

# check the attached volumes
IFS='
'
for i in `vgs --noheadings --nosuffix --units b --separator " "`;
do
    VG=`echo $i | awk -F ' ' '{ print $1}'`;
    export SIZE=`echo $i | awk -F ' ' '{ print $6}'`;
    export FREE=`echo $i | awk -F ' ' '{ print $7}'`;
    USED=$( echo "scale=2; 100 - (${FREE} * 100 / ${SIZE})" | bc );
    USED=`expr match "$USED" '\([0-9]*\)'`
            if [ $thresh_crit ] && [ "$USED" -ge "$thresh_crit" ]; then
                critflag=1
                msgs="$msgs$VG/${USED}%"
            elif [ $thresh_warn ] && [ "$USED" -ge "$thresh_warn" ]; then
                warnflag=1
                msgs="$msgs$VG/${USED}%"
            fi
done

if [ $critflag ]; then
    mesg="CRITICAL -"
    exitstatus=$STATE_CRITICAL
elif [ $warnflag ]; then
    mesg="WARNING -"
    exitstatus=$STATE_WARNING
else
    mesg="OK"
    exitstatus=$STATE_OK
fi

echo "$mesg $msgs"
exit $exitstatus
