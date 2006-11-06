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

# reality check for important configuration vars
echo "javaruntime:${JAVARUNTIMEOPTS}"
echo "classpath:${CLASSPATH}"
echo "dbserver:${MGD_DBSERVER}"
echo "database:${MGD_DBNAME}"

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
    echo "\n`date`" >> ${LOG_DIAG} ${LOG_PROC}
    echo "Files from stdin: ${APP_CAT_METHOD} ${APP_INFILES}" | tee -a ${LOG_DIAG} ${LOG_PROC}

    #
    # run spseqload
    #
    ${APP_CAT_METHOD}  ${APP_INFILES}  | \
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

#
# get input files
#
# Check to see if we're getting files from RADAR
if [  ${APP_RADAR_INPUT} = true ]
then
    APP_INFILES=`${RADAR_DBUTILS}/bin/getFilesToProcess.csh \
        ${RADAR_DBSCHEMADIR} ${JOBSTREAM} ${SEQ_PROVIDER}`
    STAT=$?
    echo "STAT from getFilesToProcess is ${STAT}"
    checkStatus ${STAT} "getFilesToProcess.csh"

    if [ "${APP_INFILES}" = "" ]
    then
	echo "No files to process" | tee -a ${LOG_DIAG} ${LOG_PROC}
	shutDown
	exit 0
    fi
fi

# if input file from Configuration check that APP_INFILES has been defined
if [ "${APP_INFILES}" = "" ]
then
     # set STAT for endJobStream.py called from postload in shutDown
    STAT=1
    checkStatus ${STAT} "APP_RADAR_INPUT=${APP_RADAR_INPUT}. Check that APP_INFILES has been configured"
fi

#
# run the load
#
run

#
# log the processed files
#
echo "Logging processed files ${APP_INFILES}" >> ${LOG_DIAG}
for file in ${APP_INFILES}
do
    ${RADAR_DBUTILS}/bin/logProcessedFile.csh ${RADAR_DBSCHEMADIR} \
	${JOBKEY} ${file}  ${SEQ_PROVIDER}
    STAT=$?
    checkStatus ${STAT} "logProcessedFile.csh"
done
echo 'Done logging processed files' >> ${LOG_DIAG}

#
# run msp qc reports
#

echo 'Running MSP QC reports' >> ${LOG_DIAG}
echo "\n`date`" >> ${LOG_DIAG}

${APP_MSP_QCRPT} ${RADAR_DBSCHEMADIR} ${MGD_DBNAME} ${JOBKEY} ${RPTDIR}
STAT=$?
checkStatus ${STAT} ${APP_MSP_QCRPT}

#
# run seqload qc reports
#

echo 'Running Sequence QC reports' >> ${LOG_DIAG}
echo "\n`date`" >> ${LOG_DIAG}

${APP_SEQ_QCRPT} ${RADAR_DBSCHEMADIR} ${MGD_DBNAME} ${JOBKEY} ${RPTDIR}
STAT=$?
checkStatus ${STAT} ${APP_SEQ_QCRPT}

#
# run postload cleanup and email logs
#
shutDown

exit 0
