BIG_CPU_PART="0xd08"
LIST_BIG_CPUS=""

find_cpu () {
    local PART=$1
    local IFS
    IFS=$'\n'

    for __LINE in $( cat /proc/cpuinfo ); do
        IFS=':'
        __TOKENS=($__LINE)
        if [ "${__LINE#'processor'}" != "$__LINE" ]; then
	    __CPU="${__TOKENS[1]##' '}"
        elif [ "${__LINE#'CPU part'}" != "$__LINE" ]; then
            __PART="${__TOKENS[1]##' '}"
            if [ "$PART" == "$__PART" ]; then
                echo -en "$__CPU "
	    fi
	fi
done
}

offline_big_cpus () {
    for CPU in ${LIST_BIG_CPUS}; do
        echo 0 > /sys/devices/system/cpu/cpu${CPU}/online
    done
}

online_big_cpus () {
    for CPU in ${LIST_BIG_CPUS}; do
        echo 1 > /sys/devices/system/cpu/cpu${CPU}/online
    done
}

LIST_BIG_CPUS="$( find_cpu ${BIG_CPU_PART} )"
