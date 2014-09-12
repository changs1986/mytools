#!/bin/bash

#auto package shell script
#default author to filter
AUTR=zhouhc
#tmp svn log file
LOGFILE=/tmp/svnlog
#where the code stays 
CODESPACE=/var/wwwroot/
#svn base url
SVNURLBATH=http://172.18.107.96/svn/
#place to put the package files
CODEOUPUT=~/

if [ $# -eq 0 ]; then
cat << HELP
	usage: -p project -s start_version -e end_version -o ver1,ver2,ver3 -n ver4,ver5 -a author 
    -o only the specify versions will be export
    -n exclude the specify versions
HELP
    exit 0
fi
#可以调整参数的顺序  
ARG=`getopt p:s:e:o:n:a: $*`  
  
#重新设置参数  
set --$ARG;  

while getopts p:s:e:o:n:a: PARAM_VAL  
do 
    case $PARAM_VAL in
    p)
        PROJECT=$OPTARG
        ;;
    s)
        SV=$OPTARG
        ;;
    e)
        EV=$OPTARG
        ;;
    o)
        VERSIONS=$OPTARG
        ;;
    n)
        EXCLUDE=$OPTARG
        ;;
    a)
        AUTR=$OPTARG
        ;;
    *)
        ;;
    esac
done

#if end_version is empty.then set end_version equal start_version
if [ "${EV}x" == 'x' ]; then
    EV=$SV
fi

#must have the test environment and local environment
case $PROJECT in 
    'ecmall')
        SVNPATH=${SVNURLBATH}ecmall2.1
        WORKING=${CODESPACE}trunk
        RELEASE=${CODESPACE}ecmall_local_2.2
        ;;
    'cpcadmin')
        SVNPATH=${SVNURLBATH}tpcpc_v1.1
        WORKING=${CODESPACE}tpcpc_v1.1
        RELEASE=${CODESPACE}cpcadmin
        ;;
    'cpc')
        SVNPATH=${SVNURLBATH}tpfcpc_v1.1
        WORKING=${CODESPACE}tpfcpc_v1.1
        RELEASE=${CODESPACE}cpc
        ;;
esac

#where to put
destDir=${CODEOUPUT}${PROJECT}

cd $WORKING

#if user specify versions
if [ $VERSIONS ]; then
    VERSIONS=(${VERSIONS//,/ })
    VERSIONS=($(printf '%d\n' "${VERSIONS[@]}"|sort -n))
    #get first version num
    SV=${VERSIONS[0]}
    #get last version num
    EV=${VERSIONS[${#VERSIONS[*]}-1]}

    #append every specify version log info into svnlog file
    for v in ${VERSIONS[@]}
    do
        svn log --incremental -r $v -v >> $LOGFILE
    done
else
    #if specify some versions not package
    if [ ${EXCLUDE} ]; then
        EXCLUDE=(${EXCLUDE//,/ })
        for ((i=$SV; i<=$EV;i++ )); 
        do
            if [[ "${EXCLUDE[@]/$i/}" == "${EXCLUDE[@]}" ]]; then
                #echo $i;
                svn log --incremental -r $i -v >> $LOGFILE
            fi
        done
    else
        svn log --incremental -r $SV:$EV -v > $LOGFILE
    fi
fi

echo '------------export start!-----------------'
if [ -f $LOGFILE ]; then
	cat $LOGFILE | while read line
	do
	    #the version info line get the version and store.
		if [ ${line:0:1}x == "r"x ]; then
            #execute command and get the author value
            VERAUTHOR=`echo $line | awk -F '|' '{printf("%s|%s",$1,$2)}' | sed 's/\s*//g'`
            #VERAUTHOR = rxxxx|yyyy split the value through |
            AUTHOR=${VERAUTHOR#*|} 
            #compare author value with the specify value
			if [ ${AUTHOR}x == ${AUTR}x ]; then
				#VER=`echo $VERAUTHOR | awk -F '|' '{print $1}'`
                VER=${VERAUTHOR%|*}
			else
				VER=0
			fi
		#get the files of modiy or add by svn cat
		elif [ "${line:0:1}x" == "Mx" ] || [ "${line:0:1}x" == "Ax" ]; then
			if [ $VER != 0 ]; then
				FPATH=${line:2}
				DESDIR=${FPATH%/*}
				if [ ! -d ${destDir}${DESDIR} ]; then
					mkdir -p ${destDir}${DESDIR}
				fi
				echo $FPATH

				#in svn add situation . if export target is a directory.then continue
		        if [ "${line:0:1}x" == "Ax" ] && [ -d "${CODESPACE}${FPATH}" ]; then
					continue
				else
					#export by svn cat
					svn cat -r ${VER:1} ${SVNPATH}${FPATH} > ${destDir}${FPATH}
				fi
			fi
		else
			continue
		fi
	done

	if [ -d ${destDir}${SV} ]; then
		rm -rf ${destDir}${SV}
	fi
	if [ -f ${destDir}${SV}.zip ]; then
		rm -f ${destDir}${SV}.zip
	fi
    
    #need to process the mall project
    if [ "${PROJECT}x" == 'ecmallx' ]; then
        mv ${destDir}/trunk/* ${destDir}    
        rm -r ${destDir}/trunk
    fi

    if [ -d ${destDir} ]; then 
        mv ${destDir} ${destDir}${SV}

        echo '-----------------export finish ! ---------------'
        #update local svn repo
        cd $RELEASE 
        svn update
        #wait a moment
        sleep 3
        meld ${destDir}${SV} $RELEASE
        
    #    #zip all the directory files
        if [ $? == 0  ]; then
            cd ${CODEOUPUT}
            zip -r ${destDir}${SV}.zip ${PROJECT}${SV}
            
            if [ $? == 0  ]; then
                rm -rf ${PROJECT}${SV}
            fi
        fi
        
        rm -f ${LOGFILE}

        echo '-------------Done----------------'
    fi
fi

