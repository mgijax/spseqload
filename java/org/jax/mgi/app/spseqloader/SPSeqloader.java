//  $Header:
//  $Name:

package org.jax.mgi.app.spseqloader;

/**
 * Debug stuff
 */
import org.jax.mgi.shr.timing.Stopwatch;

import java.util.*;


//import org.jax.mgi.shr.config.InputDataCfg;
import org.jax.mgi.shr.config.BCPManagerCfg;
import org.jax.mgi.shr.ioutils.RecordDataInterpreter;
import org.jax.mgi.shr.config.SequenceLoadCfg;
import org.jax.mgi.shr.dla.seqloader.SeqloaderConstants;
import org.jax.mgi.shr.dla.seqloader.MergeSplitProcessor;
import org.jax.mgi.shr.dla.seqloader.SeqProcessor;
import org.jax.mgi.shr.dla.seqloader.IncremSeqProcessor;
import org.jax.mgi.shr.dla.seqloader.SeqEventDetector;
import org.jax.mgi.shr.dla.seqloader.SequenceInput;
import org.jax.mgi.shr.dla.seqloader.SequenceAttributeResolver;
import org.jax.mgi.shr.dla.seqloader.EMBLOrganismChecker;
import org.jax.mgi.shr.dla.seqloader.SeqQCReporter;
import org.jax.mgi.shr.dla.seqloader.SeqloaderException;
import org.jax.mgi.shr.dla.seqloader.SeqloaderExceptionFactory;
import org.jax.mgi.shr.dla.seqloader.SequenceResolverException;
import org.jax.mgi.shr.dla.seqloader.RepeatSequenceException;
import org.jax.mgi.shr.dla.seqloader.RepeatSequenceException;
import org.jax.mgi.shr.dla.seqloader.ChangedOrganismException;
import org.jax.mgi.shr.dla.seqloader.ChangedLibraryException;
import org.jax.mgi.shr.dla.seqloader.ProcessSequenceInput;
import org.jax.mgi.shr.dla.DLALogger;
import org.jax.mgi.shr.dla.DLAException;
import org.jax.mgi.shr.dla.DLAExceptionHandler;
import org.jax.mgi.shr.dla.DLALoggingException;
import org.jax.mgi.shr.ioutils.InputDataFile;
import org.jax.mgi.shr.ioutils.RecordDataIterator;
import org.jax.mgi.shr.dbutils.SQLDataManager;
import org.jax.mgi.shr.dbutils.SQLDataManagerFactory;
import org.jax.mgi.shr.dbutils.bcp.BCPManager;
import org.jax.mgi.shr.dbutils.dao.SQLStream;
import org.jax.mgi.shr.dbutils.dao.BCP_Inline_Stream;
import org.jax.mgi.shr.dbutils.dao.BCP_Batch_Stream;
import org.jax.mgi.shr.dbutils.dao.BCP_Script_Stream;
import org.jax.mgi.shr.dbutils.ScriptWriter;
import org.jax.mgi.shr.config.ScriptWriterCfg;
import org.jax.mgi.shr.dbutils.ScriptException;
import org.jax.mgi.shr.exception.MGIException;
import org.jax.mgi.shr.ioutils.RecordFormatException;
import org.jax.mgi.shr.ioutils.IOUException;
import org.jax.mgi.shr.cache.KeyNotFoundException;
import org.jax.mgi.dbs.SchemaConstants;
import org.jax.mgi.dbs.mgd.MolecularSource.MSException;
import org.jax.mgi.dbs.mgd.lookup.TranslationException;
import org.jax.mgi.shr.config.ConfigException;
import org.jax.mgi.shr.cache.CacheException;
import org.jax.mgi.shr.dbutils.DBException;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.Runtime;

/**
 * @is
 * @has
 *   <UL>
 *   <LI>
 *   </UL>
 * @does
 *   <UL>
 *   <LI>
 *   <LI>
 *   <LI>
 *
 *   </UL>
 * @company The Jackson Laboratory
 * @author sc
 * @version 1.0
cd ../ */

public class SPSeqloader {

    // configurator for the sequence load
    private SequenceLoadCfg loadCfg;

    // the load mode
    private String loadMode;

    // Checks a record and determines if the sequence is from an organism
    // we want to load
    private EMBLOrganismChecker organismChecker;

    // Interpretor for EMBL format sequence records
    private SPSequenceInterpreter interpretor = null;

    // An input data file object for the input file.
    private InputDataFile inData = null;

    // An iterator that gets one sequence record at a time.
    private RecordDataIterator iterator = null;

    // Instance of the dataload logger for sending messages to the log files.
    private DLALogger logger = null;

    // An SQL data manager for providing a connection to the MGD database
    private SQLDataManager mgdSqlMgr = null;

    // A bcp manager for handling bcp inserts to the MGD database
    private BCPManager mgdBcpMgr = null;

    // ScriptWriter and Script cfg for writing and exec'ing update script
    private ScriptWriterCfg updateScriptCfg = null;
    private ScriptWriter updateScriptWriter = null;

    // ScriptWriter and Script cfg for writing and exec'ing mergeSplit script
    private ScriptWriterCfg mergeSplitScriptCfg = null;
    private ScriptWriter mergeSplitScriptWriter = null;

    // A stream for handling MGD DAO objects
    private BCP_Script_Stream mgdStream = null;
    //private BCP_Batch_Stream mgdStream = null;
    //private BCP_Inline_Stream mgdStream = null;

    // An SQL data manager for providing a connection to the Radar database
    private SQLDataManager rdrSqlMgr = null;

    // A bcp manager for handling bcp inserts to the Radar database
    private BCPManager rdrBcpMgr = null;

    // A stream for handling RDR DAO objects for QC reporting
    private BCP_Inline_Stream rdrStream = null;

    // A QC reporter for managing all qc reports for the seqloader
    private SeqQCReporter qcReporter = null;

    // resolves sequence attributes to MGI values
    private SequenceAttributeResolver seqResolver;

    // for processing Merges and Splits after Sequences are loaded
    MergeSplitProcessor mergeSplitProcessor;

    // the sequence processor for the load
    SeqProcessor seqProcessor;

    // file writer for repeated sequences
    private BufferedWriter repeatSeqWriter;

    SeqloaderExceptionFactory eFactory;

    /**
     * For each sequence record in the input
     *    create a SequenceInput object
     *    Call SeqProcessor.processSequence(SequenceInput)
     * After all sequences processed call
     *     Call mergeSplitProcessor.process()
     */
    public static void main(String[] args) {
        DLAException e1 = null;
        DLAExceptionHandler eh = null;
        SPSeqloader seqloader = new SPSeqloader();

        //  instantiate objects and initialize variables

        try {
            seqloader.initialize();
        }
        catch (Exception e) {
            System.out.println(e.toString());
            System.exit(1);
        }
        // load sequences
        try {
            seqloader.load();
        }
        catch (Exception e) {
            e1 = new DLAException("Sequence loader failed", false);
            e1.setParent(e);
            eh = new DLAExceptionHandler();
            eh.handleException(e1);
            System.out.println(e1.getMessage());
            System.exit(1);
        }

    }

    /**
     * what this method does ...
     * @assumes Nothing
     * @effects Nothing
     * @param None
     * @return
     * @throws Nothing
     */

    private void initialize() throws MGIException {
        MGIException.setOkToStackTrace(true);
        // get a configurator then get load mode
        loadCfg = new SequenceLoadCfg();
        loadMode = loadCfg.getLoadMode();

        // get a dataload logger
        this.logger = DLALogger.getInstance();
        //logger.setDebug(true);
        logger.logpInfo("Perform initialization", false);
        logger.logdInfo("Perform initialization", true);

        // an InputDataFile has a Configurator from which itgets its file name
        this.inData = new InputDataFile();

        // create an organism checker to pass to the interpreter
        organismChecker = new EMBLOrganismChecker();

        // Create an interpretor and get an iterator that uses that interpreter
        interpretor = new SPSequenceInterpreter(organismChecker);
        iterator = inData.getIterator(interpretor);

        /**
         * Set up MGD stream
         */
        // Create a SQLDataManager for the MGD database from the factory.
        mgdSqlMgr = SQLDataManagerFactory.getShared(SchemaConstants.MGD);
        mgdSqlMgr.setLogger(logger);

        // Create a bcp manager that has been configured for the MGD database.
        mgdBcpMgr = new BCPManager(new BCPManagerCfg("MGD"));

        // Provide the bcp manager with the SQL data manager and the logger.
        mgdBcpMgr.setSQLDataManager(mgdSqlMgr);
        mgdBcpMgr.setLogger(logger);

        // Create a stream for handling MGD DAO objects.
        //mgdStream = new BCP_Batch_Stream(mgdSqlMgr, mgdBcpMgr);
        //mgdStream = new BCP_Inline_Stream(mgdSqlMgr, mgdBcpMgr);
        updateScriptCfg = new ScriptWriterCfg("MGD");
        updateScriptWriter = new ScriptWriter(updateScriptCfg, mgdSqlMgr);

        mgdStream = new BCP_Script_Stream(updateScriptWriter, mgdBcpMgr);

        /**
         * Set up RDR stream
         */
        // Create a SQLDataManager for the Radar database from the factory.
        rdrSqlMgr = SQLDataManagerFactory.getShared(SchemaConstants.RADAR);
        rdrSqlMgr.setLogger(logger);
        // Create a bcp manager that has been configured for the MGD database.
        rdrBcpMgr = new BCPManager(new BCPManagerCfg("RADAR"));

        // Provide the bcp manager with the SQL data manager and the logger.
        rdrBcpMgr.setSQLDataManager(rdrSqlMgr);
        rdrBcpMgr.setLogger(logger);

        // Create qc reporter
        rdrStream = new BCP_Inline_Stream(rdrSqlMgr, rdrBcpMgr);
        qcReporter = new SeqQCReporter(rdrStream);

        // create a seq processor for the initial load
        seqResolver = new SequenceAttributeResolver();
        if (loadMode.equals(SeqloaderConstants.INCREM_INITIAL_LOAD_MODE) ||
            loadMode.equals(SeqloaderConstants.DELETE_RELOAD_MODE)) {
            seqProcessor = new SeqProcessor(mgdStream,
                                            rdrStream,
                                            seqResolver);
        }
        // create a seq processor for incremental loads
        else if (loadMode.equals(SeqloaderConstants.INCREM_LOAD_MODE)) {
            mergeSplitProcessor = new MergeSplitProcessor(qcReporter);
            // Note: here I want to use the default prefixing, so normally
            // wouldn't need to pass a Configurator, but the ScriptWriter(sqlMgr)
            // is a protected constructor
            mergeSplitScriptCfg = new ScriptWriterCfg();
            mergeSplitScriptWriter = new ScriptWriter(mergeSplitScriptCfg,
                mgdSqlMgr);

            // sequence loader exception factory
            eFactory = new SeqloaderExceptionFactory();
            try {
                repeatSeqWriter = new BufferedWriter(
                    new FileWriter(loadCfg.getRepeatFileName()));
            }
            catch (IOException e) {
                SeqloaderException e1 =
                    (SeqloaderException) eFactory.getException(
                    SeqloaderExceptionFactory.RepeatFileIOException, e);
                throw e1;
            }
            seqProcessor = new IncremSeqProcessor(mgdStream,
                rdrStream,
                qcReporter,
                seqResolver,
                mergeSplitProcessor,
                repeatSeqWriter);
        }
    }

    /**
     * what this method does ...
     * @assumes Nothing
     * @effects
     * @param None
     * @return Nothing
     * @throws DBException if problem closing rdrStream or mgdStream
     * @throws IOUException if problems calling SequenceInput iterator.next()
     * @throws ScriptException if error writing to or executing the
     *          mergeSplitScriptWriter
     * @throws SeqloaderException if error closing the repeate sequence writer
     */

    private void load() throws DBException, IOUException, ScriptException,
        SeqloaderException {

        // Timing the load
        Stopwatch loadStopWatch = new Stopwatch();
        loadStopWatch.start();

        // For memory usage
        Runtime runTime = Runtime.getRuntime();

        // Timing individual sequence processing
        Stopwatch sequenceStopWatch = new Stopwatch();

        long runningFreeMemory = 0;
        long currentFreeMemory = 0;
        int seqCtr = 0;

        // Data object representing the current record in the input
        SequenceInput si;

        // number of valid sequences WITHOUT processing errors:
        int passedCtr = 0;

        // number of valid sequences WITH processing errors
        int errCtr = 0;

        // if we are in delete/reload mode - call the delete method on the processor
        // could just call the delete method - because if it is not delete/reload mode it
        // it won't do anything
        if (loadMode.equals(SeqloaderConstants.DELETE_RELOAD_MODE)) {
            logger.logdInfo("Deleting sequences", true);
            seqProcessor.deleteSequences();
            logger.logdInfo("Done deleting Sequences", true);
        }

        // get the next record
        while (iterator.hasNext()) {
            sequenceStopWatch.reset();
            sequenceStopWatch.start();
            try {

                // interpret next record

                si = (SequenceInput) iterator.next();
                //System.out.println(si.getPrimaryAcc().getAccID());
            }
            catch (RecordFormatException e) {
                logger.logdErr(e.getMessage());
                errCtr++;
                continue;
            }
            try {
                seqProcessor.processInput(si);
            }
            // log repeat sequence, go to next sequence
            catch (RepeatSequenceException e) {
                String message = e.getMessage() + " Sequence: " +
                    si.getPrimaryAcc().getAccID();
                logger.logdInfo(message, true);
                logger.logcInfo(message, true);

                continue;
            }
            // log changed organism, go to next sequence
            catch (ChangedOrganismException e) {
                String message = e.getMessage() + " Sequence: " +
                    si.getPrimaryAcc().getAccID();
                logger.logdInfo(message, true);
                logger.logcInfo(message, true);

                errCtr++;
                continue;
            }
            // log changed library, go to next sequence
            catch (ChangedLibraryException e) {
                String message = e.getMessage() + " Sequence: " +
                    si.getPrimaryAcc().getAccID();
                logger.logdInfo(message, true);
                logger.logcInfo(message, true);

                errCtr++;
                continue;
            }
            // if we can't resolve SEQ_Sequence attributes, go to the next
            // sequence
            catch (SequenceResolverException e) {
                String message = e.getMessage() + " Sequence: " +
                    si.getPrimaryAcc().getAccID();
                logger.logdInfo(message, true);
                logger.logcInfo(message, true);

                errCtr++;
                continue;
            }
            // if we can't resolve the source for a sequence, go to the next
            // sequence
            catch (MSException e) {
                String message = e.getMessage() + " Sequence: " +
                    si.getPrimaryAcc().getAccID();
                logger.logdInfo(message, true);
                logger.logcInfo(message, true);

                errCtr++;
                continue;
            }

            //DEBUG
            //currentFreeMemory = runTime.freeMemory();
            //runningFreeMemory = runningFreeMemory + currentFreeMemory;

            seqCtr = passedCtr + errCtr;
            if (seqCtr > 0 && seqCtr % 1000 == 0) {
                logger.logdInfo("Processed " + seqCtr + " input records", false);
                //System.gc();
                //logger.logdInfo("Total Memory Available to the VM: " + runTime.totalMemory(), false);
                //logger.logdInfo("Free Memory Available: " + currentFreeMemory, false);
            }

            passedCtr++;
            sequenceStopWatch.stop();
            logger.logdDebug("MEM&TIME: " + (passedCtr + errCtr) + "\t" +
                             currentFreeMemory + "\t" + sequenceStopWatch.time(), false);
        }
        // get the sequence processing time
        loadStopWatch.stop();
        double totalProcessTime = loadStopWatch.time();

        // processes inserts, deletes and updates to mgd
        logger.logdInfo("Closing mgdStream", false);
        mgdStream.close();

        //  process merges and splits - note: all adds and updates must
        // already be processed (mgdstream must already be closed).
        if (loadMode.equals(SeqloaderConstants.INCREM_LOAD_MODE)) {
          logger.logdInfo("Processing Merge/Splits", true);
          mergeSplitProcessor.process(mergeSplitScriptWriter);
          mergeSplitScriptWriter.execute();
          logger.logdInfo("Finished processing Merge/Splits", true);

          // close the repeat sequence writer
          try {
            repeatSeqWriter.close();
          }
          catch (IOException e) {
            SeqloaderException e1 =
                (SeqloaderException) eFactory.getException(
                SeqloaderExceptionFactory.RepeatFileIOException, e);
            throw e1;
          }
        }

        // Close rdrStream after all qc reporting has been done - Note that
        // mergeSplitProcessor does qc reporting
        logger.logdInfo("Closing rdrStream", false);
        rdrStream.close();

        /**
        * report Sequence processing statistics
        */

        logger.logdInfo("Total SPSeqloader.load() time in minutes: " +
                        (totalProcessTime/60), true);
        logger.logpInfo("Total SPSeqloader.load() time in minutes: " +
                        (totalProcessTime/60), true);

        seqCtr = passedCtr + errCtr;
        logger.logdInfo("Total Sequences Processed = " + seqCtr + " (" + errCtr +
                        " skipped because of errors - see QC reports and diagnostic log)", false);
        logger.logpInfo("Total Sequence Processed = " + seqCtr + " (" + errCtr +
                        " skipped because of errors - see QC reports and diagnostic log)", false);

        logger.logdDebug("Average Processing Time/Sequence = " +
                        (totalProcessTime / seqCtr), false);

        if (seqCtr > 0) {
          logger.logdDebug("Average SequenceLookup time = " +
                          (seqProcessor.runningLookupTime / seqCtr), false);

          logger.logdDebug("Greatest SequenceLookup time = " +
                           seqProcessor.highLookupTime, false);
          logger.logdDebug("Least SequenceLookup time = " +
                           seqProcessor.lowLookupTime, false);

          // report MSProcessor execution times
          logger.logdDebug("Average MSProcessor time = " +
                           (seqProcessor.runningMSPTime / seqCtr), false);
          logger.logdDebug("Greatest MSProcessor time = " +
                           seqProcessor.highMSPTime, false);
          logger.logdDebug("Least MSProcessor time = " + seqProcessor.lowMSPTime, false);
          // report free memory average
          logger.logdDebug("Average Free Memory = " + (runningFreeMemory / seqCtr), false);
        }
        logger.logdInfo("Organism Decider Counts:", false);
        logger.logpInfo("Organism Decider Counts:", false);

        Vector deciderCts = organismChecker.getDeciderCounts();
        for (Iterator i = deciderCts.iterator(); i.hasNext(); ) {
            String line = (String) i.next();
            logger.logdInfo( line, false);
            logger.logpInfo( line, false);
        }

        // report Event counts for sequences processed - Note that all
        // Merge and Split events are also other events. e.g. if two sequences
        // are merged into one new sequence than there will be an add
        // event and two merge events. If a sequence is merged into an existing
        // sequence then there will be an update event and one merge event.
        // if a sequence is split into two new sequences then there will be two
        // add events and one split event.

        Vector eventReports = seqProcessor.getProcessedReport();
        for(Iterator i = eventReports.iterator(); i.hasNext();) {
              String line = (String)i.next();
              logger.logpInfo(line, false);
              logger.logdInfo(line, false);
        }
    }
}
// $Log