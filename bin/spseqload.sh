#!/bin/sh
#
#  $Header
#  $Name
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
#      - Common configuration file (/usr/local/mgi/etc/common.config.sh)
#      - SwissProt/TrEMBL common configuration file (sp_common.config)
#      - SwissProt or TrEMBL configuration file (spseqload.config or
#             trseqload.config)
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
#      - QC reports as defined by ${SEQLOAD_QCRPT} and ${MSP_QCRPT}
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
CONFIG_COMMON=`pwd`/common.config.sh
CONFIG_LOAD=`pwd`/$1
CONFIG_SPCOMMON=`pwd`/sp_common.config

echo ${CONFIG_LOAD}

#
#  Make sure the configuration files are readable.
#
if [ ! -r ${CONFIG_COMMON} ]
then
    echo "Cannot read configuration file: ${CONFIG_COMMON}" | tee -a ${LOG}
    exit 1
fi

if [ ! -r ${CONFIG_LOAD} ]
then
    echo "Cannot read configuration file: ${CONFIG_LOAD}" | tee -a ${LOG}
    exit 1
fi

if [ ! -r ${CONFIG_SPCOMMON} ]
then
    echo "Cannot read configuration file: ${CONFIG_SPCOMMON}" | tee -a ${LOG}
    exit 1
fi

#
#  Concatenate the configuration files together to produce one configuration
#  file that can be run to set up the environment. CONFIG_SPCOMMON is depend
#  ent on CONFIG_LOAD
#
CONFIG_RUNTIME=`pwd`/runtime.config
cat ${CONFIG_COMMON} ${CONFIG_LOAD} ${CONFIG_SPCOMMON} > ${CONFIG_RUNTIME}
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
    # call DLA library function
    #
    postload

    #
    #  Mail the logs to the support staff.
    #
    if [ "${MAIL_LOG_PROC}" != "" ]
    then
        mailLog ${MAIL_LOG_PROC} "SwissProt Load - Process Summary Log" \
	    ${LOG_PROC} | tee -a ${LOG}
    fi

    if [ "${MAIL_LOG_CUR}" != "" ]
    then
        mailLog ${MAIL_LOG_CUR} "SwissProt Load - Curator Summary Log" \
	    ${LOG_CUR} | tee -a ${LOG}
    fi
}

#
# Function that runs to java load
#

run ()
{
    #
    # log time and input files to process
    #
    echo "\n`date`" >> ${LOG_PROC}
    echo "Files from stdin: ${CAT_METHOD} ${PIPED_INFILES}" | tee -a ${LOG_DIAG} 
    #
    # run spseqload
    #
    ${CAT_METHOD}  ${PIPED_INFILES}  | \
	${JAVA_RUN} ${JAVARUNTIMEOPTS} -classpath ${CLASSPATH} \
	-DCONFIG=${CONFIG_RUNTIME} -DJOBKEY=${JOBKEY} \
	${SPSEQLOAD_APP} | tee -a  ${LOGDIR}/stdouterr

    STAT=$?
    if [ ${STAT} -ne 0 ]
    then
	echo "spseqload processing failed.  \
	    Return status: ${STAT}" >> ${LOG_PROC}
	shutDown
	exit 1
    fi
}

##################################################################
# main
##################################################################

#
# createArchive, startLog, getConfigEnv, get job key
#
preload

#
# get input files
#
# Check to see if we're getting files from RADAR
echo "RADAR_INPUT=${RADAR_INPUT}"
if [  ${RADAR_INPUT} = true ]
then
    echo "call to getFiles: ${RADARDBUTILSDIR}/bin/getFilesToProcess.csh ${RADAR_DBSCHEMADIR} ${JOBSTREAM} ${SEQ_PROVIDER}"
    PIPED_INFILES=`${RADARDBUTILSDIR}/bin/getFilesToProcess.csh \
        ${RADAR_DBSCHEMADIR} ${JOBSTREAM} ${SEQ_PROVIDER}`
    STAT=$?
    if [ ${STAT} -ne 0 ]
    then
	echo "getFilesToProcess.csh failed.  \
	    Return status: ${STAT}" >> ${LOG_PROC}
	shutDown
	exit 1
    fi
    if [ "${PIPED_INFILES}" = "" ]
    then
	echo "No files to process" | tee -a ${LOG_DIAG}
    shutDown
    exit 0
fi

fi
# if input file from Configuration check that PIPED_INFILES has been defined
if [ "${PIPED_INFILES}" = "" ]
then
    echo "RADAR_INPUT=false. Check that PIPED_INFILES has been configured" | tee -a ${LOG_DIAG}
    # set STAT for endJobStream.py called from postload in shutDown
    STAT=1
    shutDown
    exit 0
fi

#
# run the load
#
run

#
# log the processed files
#
if [  ${RADAR_INPUT} = true ]
then

    echo "Logging processed files ${PIPED_INFILES}" | tee -a ${LOG_DIAG}
    for file in ${PIPED_INFILES}
    do
	${RADARDBUTILSDIR}/bin/logProcessedFile.csh ${RADAR_DBSCHEMADIR} \
	    ${JOBKEY} ${file}
	STAT=$?
	if [ ${STAT} -ne 0 ]
	then
	    echo "logProcessedFile.csh failed.  \
		Return status: ${STAT}" >> ${LOG_PROC}
	    shutDown
	    exit 1
	fi

    done
    echo 'Done logging processed files' | tee -a ${LOG_DIAG}
fi

#
# run msp qc reports
#
${MSP_QCRPT} ${RADAR_DBSCHEMADIR} ${MGD_DBNAME} ${JOBKEY} ${RPTDIR}
STAT=$?
if [ ${STAT} -ne 0 ]
then
    echo "Running MSP QC reports failed.  Return status: ${STAT}" >> ${LOG_PROC}
    shutDown
    exit 1
fi

#
# run seqload qc reports
#
${SEQLOAD_QCRPT} ${RADAR_DBSCHEMADIR} ${MGD_DBNAME} ${JOBKEY} ${RPTDIR}
STAT=$?
if [ ${STAT} -ne 0 ]
then
    echo "Running seqloader QC reports failed.  Return status: ${STAT}" >> ${LOG_PROC}
    shutDown
    exit 1
fi

#
# run postload cleanup and email logs
#
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
