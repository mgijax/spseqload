package org.jax.mgi.app.spseqloader;

import org.jax.mgi.shr.timing.Stopwatch;
import org.jax.mgi.shr.dla.input.embl.EMBLOrganismChecker;
import org.jax.mgi.shr.dla.loader.seq.SeqLoader;
import org.jax.mgi.shr.dla.input.embl.EMBLInputFileNoSeq;
import org.jax.mgi.shr.exception.MGIException;
import java.util.Vector;
import java.util.Iterator;


/**
 * @is an object which extends Seqloader and implements the Seqloader
 * getRecordDataIterator method to set Seqloader's OrganismChecker and
 * RecordDataIterator
 *
 * @has See superclass
 *
 * @does
 * <UL>
 * <LI>implements superclass (Seqloader) getRecordDataIterator to set superclass
 *     OrganismChecker with an EMBLOrganismChecker and create the
 *     superclass RecordDataIterator from an EMBLInputFile
 * <LI>It has an empty implementation of the superclass (DLALoader)
 *     preProcess method
 * <LI>It has an empty implementation of the superclass (Seqloader)
 *     appPostProcess method.
 * </UL>
 * @author sc
 * @version 1.0
 */


public class SPSeqloader extends SeqLoader {

    /**
      * This load has no preprocessing
      * @assumes nothing
      * @effects noting
      * @throws MGIException if errors occur during preprocessing
      */

    protected void preprocess() { }

    /**
     * Create a RecordDataIterator for the SwissProt input file
     * Sets the superclass OrganismChecker
     * GBSequenceInterpreter
     * @assumes nothing
     * @effects nothing
     * @throws nothing
     */
    protected void getDataIterator() throws MGIException {

        // create an organism checker for the interpreter
        EMBLOrganismChecker oc = new EMBLOrganismChecker();

        // set oc in the superclass for reporting purposes
        super.organismChecker = oc;

        // Create an EMBLInputFile
        //SPSequenceInterpreter interp = new SPSequenceInterpreter(oc);
        EMBLInputFileNoSeq inData = new EMBLInputFileNoSeq();

        // get an iterator for the EMBLInputFile with a SwissProt interpreter
        super.iterator = inData.getIterator(new SPSequenceInterpreter(oc));
    }

   protected void appPostProcess() throws MGIException {

   }
}
