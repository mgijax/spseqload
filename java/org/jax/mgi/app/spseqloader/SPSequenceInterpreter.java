//  $Header
//  $Name

package org.jax.mgi.app.spseqloader;

import java.util.*;
import java.util.regex.*;
import java.sql.*;

import org.jax.mgi.shr.dla.input.SequenceInterpreter;
import org.jax.mgi.shr.dla.input.SequenceInput;
import org.jax.mgi.shr.dla.loader.seq.SeqloaderConstants;
import org.jax.mgi.dbs.mgd.loads.SeqRefAssoc.SeqRefAssocPair;
import org.jax.mgi.shr.dla.input.DateConverter;
import org.jax.mgi.dbs.mgd.loads.Acc.AccessionRawAttributes;
import org.jax.mgi.dbs.mgd.loads.SeqRefAssoc.RefAssocRawAttributes;
import org.jax.mgi.dbs.mgd.loads.Seq.SequenceRawAttributes;
import org.jax.mgi.shr.dla.input.embl.EMBLFormatInterpreter;
import org.jax.mgi.shr.dla.input.embl.EMBLOrganismChecker;
import org.jax.mgi.shr.config.ConfigException;
import org.jax.mgi.shr.ioutils.RecordFormatException;
import org.jax.mgi.shr.stringutil.StringLib;
import org.jax.mgi.dbs.mgd.loads.SeqSrc.MSRawAttributes;


    /**
     * @is An object that parses a SwissProt sequence record and obtains values
     *     from a Configurator to create a SequenceInput data object.<BR>
     *     Determines if a SwissProt sequence record is valid.
     * @has
     *   <UL>
     *   <LI>A SequenceInput object into which it bundles:
     *   <LI>A SequenceRawAttributes object
     *   <LI>An AccessionRawAttributes object for its primary seqid
     *   <LI>One AccessionRawAttributes object for each secondary seqid
     *   <LI> A RefAssocRawAttributes object for each reference that has a
     *        PubMed and/or Medline id
     *   <LI> A MSRawAttributes
     *   <LI> See also superclass
     *   </UL>
     * @does
     *   <UL>
     *   <LI>Determines if a SwissProt sequence record is valid
     *   <LI>Parses a SwissProt sequence record
     *   </UL>
     * @company The Jackson Laboratory
     * @author sc
     * @version 1.0
     */

public class SPSequenceInterpreter extends EMBLFormatInterpreter {

    private SequenceInput seqInput;
    // quality and type for SwissProt records
    private String sequenceType;
    private String sequenceQuality;

    public SPSequenceInterpreter(EMBLOrganismChecker oc) throws ConfigException {
        super(oc);
        // get SwissProt type and quality from configurator
        sequenceType = sequenceCfg.getSeqType();
        sequenceQuality = sequenceCfg.getQuality();
    }
    /**
     * Parses a sequence record and  creates a SequenceInput object from
     * Configuration and parsed values. Sets sequence Quality for GenBank
     * sequences by division
     * @assumes Nothing
     * @effects Nothing
     * @param rcd A sequence record
     * @return A SequenceInput object representing 'rcd'
     * @throws RecordFormatException if we can't parse an attribute because of
     *         record formatting errors
     */

    public Object interpret(String rcd) throws RecordFormatException {
        // call superclass to parse the record and get config
        seqInput = (SequenceInput)super.interpret(rcd);

        // get the rawSeq and set type and quality
        SequenceRawAttributes rawSeq = seqInput.getSeq();
        rawSeq.setType(sequenceType);
	    rawSeq.setQuality(sequenceQuality);

        // get rawMS and set strain, tissue, gender, library and cell line
        // to 'Not Applicable' Note: when we get the rawMS all these attributes
        // are null because they are not parsed from the seq record. The MS
        // processer sets null (mouse only) source attributes to 'Not Resolved'
        // we override that here.
        /*
       Vector rawMS = seqInput.getMSources();
       MSRawAttributes currentMS;
       for (Iterator i = rawMS.iterator(); i.hasNext();) {
           currentMS = (MSRawAttributes)i.next();
           currentMS.setStrain(SeqloaderConstants.NOT_APPLICABLE);
           currentMS.setTissue(SeqloaderConstants.NOT_APPLICABLE);
           currentMS.setGender(SeqloaderConstants.NOT_APPLICABLE);
           currentMS.setCellLine(SeqloaderConstants.NOT_APPLICABLE);
           currentMS.setAge(SeqloaderConstants.NOT_APPLICABLE);
       }
      */
        // return the SequenceInput object with all SwissProt attributes set
        return seqInput;
    }
}

//  $Log

/**************************************************************************
*
* Warranty Disclaimer and Copyright Notice
*
*  THE JACKSON LABORATORY MAKES NO REPRESENTATION ABOUT THE SUITABILITY OR
*  ACCURACY OF THIS SOFTWARE OR DATA FOR ANY PURPOSE, AND MAKES NO WARRANTIES,
*  EITHER EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS FOR A
*  PARTICULAR PURPOSE OR THAT THE USE OF THIS SOFTWARE OR DATA WILL NOT
*  INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS, OR OTHER RIGHTS.
*  THE SOFTWARE AND DATA ARE PROVIDED "AS IS".
*
*  This software and data are provided to enhance knowledge and encourage
*  progress in the scientific community and are to be used only for research
*  and educational purposes.  Any reproduction or use for commercial purpose
*  is prohibited without the prior express written permission of The Jackson
*  Laboratory.
*
* Copyright \251 1996, 1999, 2002, 2003 by The Jackson Laboratory
*
* All Rights Reserved
*
**************************************************************************/
