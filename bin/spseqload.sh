#!/bin/sh
#
#  $Header
#  $Name
#
#  spseqload.sh
###########################################################################
#
#  Purpose:  This script controls the execution of the SwissProt Sequence Load
#
#  Usage:
#
#      spseqload.sh
#
#  Env Vars:
#
#      See the configuration file
#
#  Inputs:
#
#      - Common configuration file (/usr/local/mgi/etc/common.config.sh)
#      - SwissProt load configuration file (spseqload.config)
#      - One or more SwissProt input files 
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
if [ $# -ne 0 ]
then
    echo "Usage: $0" | tee -a ${LOG}
    exit 1
fi

#
#  Establish the configuration file names.
#
CONFIG_COMMON=`pwd`/common.config.sh
CONFIG_SPLOAD=`pwd`/spseqload.config
echo ${CONFIG_SPLOAD}

#
#  Make sure the configuration files are readable.
#
if [ ! -r ${CONFIG_COMMON} ]
then
    echo "Cannot read configuration file: ${CONFIG_COMMON}" | tee -a ${LOG}
    exit 1
fi
if [ ! -r ${CONFIG_SPLOAD} ]
then
    echo "Cannot read configuration file: ${CONFIG_SPLOAD}" | tee -a ${LOG}
    exit 1
fi

#
#  Concatenate the configuration files together to produce one configuration
#  file that can be run to set up the environment.
#
CONFIG_RUNTIME=`pwd`/runtime.config
cat ${CONFIG_COMMON} ${CONFIG_SPLOAD} > ${CONFIG_RUNTIME}
. ${CONFIG_RUNTIME}

echo "javaruntime:${JAVARUNTIMEOPTS}"
echo "classpath:${CLASSPATH}"
echo "dbserver:${MGD_DBSERVER}"
echo "database:${MGD_DBNAME}"

#
#  Include the DLA library functions.
#
. ${DLAFUNCTIONS}

#
#  Function that performs cleanup tasks for the job stream prior to
#  termination.
#
shutDown ()
{
    #
    #  End the job stream if a new job key was successfully obtained.
    #  The STAT variable will contain the return status from the data
    #  provider loader or the clone loader.
    #
    if [ ${JOBKEY} -gt 0 ]
    then
        echo "End the job stream" >> ${LOG_PROC}
        ${JOBEND_CSH} ${RADAR_DBSCHEMADIR} ${JOBKEY} ${STAT}
    fi
    #
    #  End the log files.
    #
    stopLog ${LOG_PROC} ${LOG_DIAG} ${LOG_CUR} ${LOG_VAL} | tee -a ${LOG}

    #
    #  Mail the logs to the support staff.
    #
    if [ "${MAIL_LOG_PROC}" != "" ]
    then
        mailLog ${MAIL_LOG_PROC} "SwissProt Load - Process Summary Log" ${LOG_PROC} | tee -a ${LOG}
    fi

    if [ "${MAIL_LOG_CUR}" != "" ]
    then
        mailLog ${MAIL_LOG_CUR} "SwissProt Load - Curator Summary Log" ${LOG_CUR} | tee -a ${LOG}
    fi
}


#
#  Archive the log and report files from the previous run.
#
createArchive ${ARCHIVEDIR} ${LOGDIR} ${RPTDIR} | tee -a ${LOG}

#
#  Initialize the log files.
#
startLog ${LOG_PROC} ${LOG_DIAG} ${LOG_CUR} ${LOG_VAL} | tee -a ${LOG}

#
#  Write the configuration information to the log files.
#
getConfigEnv >> ${LOG_PROC}
getConfigEnv -e >> ${LOG_DIAG}
echo "Files from stdin: ${CAT_METHOD} ${PIPED_INFILES}" >> ${LOG_DIAG}
#
#  Start a new job stream and get the job stream key.
#
echo "Start a new job stream" >> ${LOG_PROC}
JOBKEY=`${JOBSTART_CSH} ${RADAR_DBSCHEMADIR} ${JOBSTREAM}`
if [ $? -ne 0 ]
then
    echo "Could not start a new job stream for this load" >> ${LOG_PROC}
    shutDown
    exit 1
fi
echo "JOBKEY=${JOBKEY}" >> ${LOG_PROC}

#
#  Run spseqload
#
echo "\n`date`" >> ${LOG_PROC}
echo "${CAT_METHOD} ${PIPED_INFILES}"
echo 'Partitioning ACC_Accession, SEQ_Sequence, SEQ_Source_Assoc'
${MGD_DBSCHEMADIR}/partition/ACC_Accession_create.object
${MGD_DBSCHEMADIR}/partition/SEQ_Sequence_create.object
${MGD_DBSCHEMADIR}/partition/SEQ_Source_Assoc_create.object

#gunzip -c 
#cat 
${CAT_METHOD} ${PIPED_INFILES} | ${JAVA_RUN} ${JAVARUNTIMEOPTS} -classpath ${CLASSPATH} -DCONFIG=${CONFIG_SPLOAD} -DJOBKEY=${JOBKEY} ${SPSEQLOAD_APP} 
#| tee -a ${LOGDIR}/spseqloadProfile.txt

#-Xrunhprof:file=${LOGDIR}/spseqloadProfile.txt,format=b ${SPSEQLOAD_APP}

STAT=$?
if [ ${STAT} -ne 0 ]
then
    echo "spseqload failed.  Return status: ${STAT}" >> ${LOG_PROC}
    shutDown
    exit 1
fi

# temporarily call this during testing to create a sequence status as deleted
/home/lec/db/mgidbmigration/JSAM/deletedSequence.csh ${MGD_DBSCHEMADIR}
STAT=$?
if [ ${STAT} -ne 0 ]
then
    echo "deleteSequence.csh failed.  Return status: ${STAT}" >> ${LOG_PROC}
    shutDown
    exit 1
fi

echo "spseqload completed successfully" >> ${LOG_PROC}

shutDown

exit 0

$Log

###########################################################################
#
# Warranty Disclaimer and Copyright Notice
#
#  THE JACKSON LABORATORY MAKES NO REPRESENTATION ABOUT THE SUITABILITY OR
#  ACCURACY OF THIS SOFTWARE OR DATA FOR ANY PURPOSE, AND MAKES NO WARRANTIES,
#  EITHER EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS FOR A
#  PARTICULAR PURPOSE OR THAT THE USE OF THIS SOFTWARE OR DATA WILL NOT
#  INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS, OR OTHER RIGHTS.
#  THE SOFTWARE AND DATA ARE PROVIDED "AS IS".
#
#  This software and data are provided to enhance knowledge and encourage
#  progress in the scientific community and are to be used only for research
#  and educational purposes.  Any reproduction or use for commercial purpose
#  is prohibited without the prior express written permission of The Jackson
#  Laboratory.
#
# Copyright \251 1996, 1999, 2002, 2003 by The Jackson Laboratory
#
# All Rights Reserved
#
###########################################################################
