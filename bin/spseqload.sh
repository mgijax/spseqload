#!/bin/sh 
#
#  spseqload.sh
###########################################################################
#
#  Purpose:  This script controls the execution of the SwissProt
#		and TrEMBL Sequence Loads
#
   Usage="spseqload.sh config_file"
#      e.g. spseqload.sh trseqload.config
#
#  Env Vars:
#
#      See the configuration file
#
#  Inputs:
#
#      - Common configuration file - 
#		/usr/local/mgi/live/mgiconfig/master.config.sh
#      - SwissProt/TrEMBL common configuration file - sp_common.config
#      - SwissProt or TrEMBL configuration file - spseqload.config or
#             trseqload.config
#      - One or more  SwissProt/TrEMBL input files 
#
#  Outputs:
#
#      - An archive file
#      - Log files defined by the environment variables ${LOG_PROC},
#        ${LOG_DIAG}, ${LOG_CUR} and ${LOG_VAL}
#      - BCP files for for inserts to each database table to be loaded
#      - SQL script file for updates
#      - Records written to the database tables
#      - Exceptions written to standard error
#      - Configuration and initialization errors are written to a log file
#        for the shell script
#      - QC reports as defined by ${APP_SEQ_QCRPT} and ${APP_MSP_QCRPT}
#        
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#      2:  Non-fatal error occurred
#
#  Assumes:  Nothing
#
#  Implementation:  
#
#  Notes:  None
#
###########################################################################

#
#  Set up a log file for the shell script in case there is an error
#  during configuration and initialization.
#
cd `dirname $0`/..
LOG=`pwd`/spseqload.log
rm -f ${LOG}

#
#  Verify the argument(s) to the shell script.
#
if [ $# -ne 1 ]
then
    echo ${Usage} | tee -a ${LOG}
    exit 1
fi

#
#  Establish the configuration file names.
#
CONFIG_LOAD=`pwd`/$1
CONFIG_LOAD_COMMON=`pwd`/sp_common.config

#
#  Make sure the configuration files are readable.
#

if [ ! -r ${CONFIG_LOAD} ]
then
    echo "Cannot read configuration file: ${CONFIG_LOAD}" | tee -a ${LOG}
    exit 1
fi

if [ ! -r ${CONFIG_LOAD_COMMON} ]
then
    echo "Cannot read configuration file: ${CONFIG_LOAD_COMMON}" | tee -a ${LOG}
    exit 1
fi

#
# Source the SwissProt Load configuration files - order is important
#
. ${CONFIG_LOAD_COMMON}
. ${CONFIG_LOAD}

#
#  Make sure the master configuration file is readable
#

if [ ! -r ${CONFIG_MASTER} ]
then
    echo "Cannot read configuration file: ${CONFIG_MASTER}"
    exit 1
fi

#
#  Source the DLA library functions.
#
if [ "${DLAJOBSTREAMFUNC}" != "" ]
then
    if [ -r ${DLAJOBSTREAMFUNC} ]
    then
        . ${DLAJOBSTREAMFUNC}
    else
        echo "Cannot source DLA functions script: ${DLAJOBSTREAMFUNC}"
        exit 1
    fi
else
    echo "Environment variable DLAJOBSTREAMFUNC has not been defined."
fi

#
# Function that runs the java load
#

run ()
{
    #
    # log time and input files to process
    #
    echo "" >> ${LOG_DIAG} ${LOG_PROC}
    echo "`date`" >> ${LOG_DIAG} ${LOG_PROC}
    echo "File from stdin: ${APP_CAT_METHOD} ${APP_INFILE}" >> ${LOG_DIAG} ${LOG_PROC}

    #
    # run spseqload
    #
    ${APP_CAT_METHOD}  ${APP_INFILE}  | \
	${JAVA} ${JAVARUNTIMEOPTS} -classpath ${CLASSPATH} \
	-DCONFIG=${CONFIG_MASTER},${CONFIG_LOAD_COMMON},${CONFIG_LOAD} \
	-DJOBKEY=${JOBKEY} ${DLA_START}
    STAT=$?
    checkStatus ${STAT} ${SPSEQLOAD} ${CONFIG_LOAD}
}

##################################################################
##################################################################
#
# main
#
##################################################################
##################################################################

#
# createArchive including OUTPUTDIR, startLog, getConfigEnv, get job key
#
preload ${OUTPUTDIR}


#
# rm all files/dirs from OUTPUTDIR and RPTDIR
#
cleanDir ${OUTPUTDIR} ${RPTDIR}

# check that APP_INFILE has been defined
if [ "${APP_INFILE}" = "" ]
then
     # set STAT for endJobStream.py called from postload in shutDown
    STAT=1
    checkStatus ${STAT} "Check that APP_INFILE has been configured"
fi

# Get read lock on the blast directory
${MIRROR_LOCK} ${READ_LOCK} ${LOCKNAME} ${BLASTDIR}
STAT=$?
if [ $STAT -gt 0 ]
then
    checkStatus $STAT "There is a write lock on the input directory ${BLASTDIR}. ${SPSEQLOAD} exiting"
fi

#
# There should be a "lastrun" file in the input directory that was created
# the last time the load was run for this input file. If this file exists
# and is more recent than the input file, the load does not need to be run.
#
LASTRUN_FILE=${INPUTDIR}/lastrun
echo "LASTRUN_FILE: ${LASTRUN_FILE}"
if [ -f ${LASTRUN_FILE} ]
then
    if /usr/local/bin/test ${LASTRUN_FILE} -nt ${APP_INFILE}
    then

        echo "Input file has not been updated - skipping load" | tee -a ${LOG_PROC}
	# unlock the input directory
	${MIRROR_LOCK} ${UNLOCK} ${LOCKNAME} ${BLASTDIR}

        # set STAT for shutdown
        STAT=0
        echo 'shutting down'
        shutDown
        exit 0
    fi
fi

#
# run the load
#
run

#
# unlock the input directory
#
${MIRROR_LOCK} ${UNLOCK} ${LOCKNAME} ${BLASTDIR} 

#
# Archive a copy of the input file, adding a timestamp suffix.
#
echo "" >> ${LOG_DIAG}
date >> ${LOG_DIAG}
echo "Archive input file" >> ${LOG_DIAG}
TIMESTAMP=`date '+%Y%m%d.%H%M'`
ARC_FILE=`basename ${APP_INFILE}`.${TIMESTAMP}
cp -p ${APP_INFILE} ${ARCHIVEDIR}/${ARC_FILE}

#
# Touch the "lastrun" file to note when the load was run.
#
if [ ${STAT} = 0 ]
then
    touch ${LASTRUN_FILE}
fi

#
# run postload cleanup and email logs
#
shutDown

exit 0
