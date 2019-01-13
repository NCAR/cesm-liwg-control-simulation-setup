#!/bin/bash

#TODO: CHECK TOPO FORCING

D=$PWD
User=katec

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=6
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_
    BG_Restart_Year_Short=36
    BG_Restart_Year=`printf %04d $BG_Restart_Year_Short`
    BG_Forcing_Year_Start=6
    let BG_Forcing_Year_End=BG_Restart_Year_Short-1
    Outputroot=/glade/scratch/$User/CESM21-CISM2-JG-BG-Dec2018
    
    #Set name of simulation
    CaseName=$JG_CaseName_Root"$t"
    PreviousBGCaseName="$BG_CaseName_Root""$tm1"
    JG_t_RunDir=$Outputroot/$CaseName/run
    JG_t_ArchiveDir=$Outputroot/archive/$CaseName
    BG_tm1_cpl_Dir=$Outputroot/archive/"$PreviousBGCaseName"/cpl/hist/
    BG_tm1_rest_Dir=$Outputroot/archive/"$PreviousBGCaseName"/rest/"$BG_Restart_Year"-01-01-00000/
    BG_tm1_ocn_restoring_Dir=$Outputroot/archive/"$PreviousBGCaseName"/ocn/hist/

###set project code
    ProjCode=P93300301

###set up model
    #Set the source code from which to build model
    CCSMRoot=$D/Model_Version/cesm2.1.0+cism2_1_66

    echo '****'
    echo "Building code from $CCSMRoot"

    $CCSMRoot/cime/scripts/create_newcase --case $D/$CaseName --output-root $Outputroot --compset 1850_DATM%CRU_CLM50%BGC-CROP_CICE_POP2%ECO_MOSART_CISM2%EVOLVE_WW3_BGC%BDRD --res f09_g17_gl4 --mach cheyenne --project $ProjCode --run-unsupported 
			   
    #Change directories into the new experiment case directory
    cd $D/$CaseName
    ./xmlchange RUNDIR=$JG_t_RunDir

###Set customized PE layout
    #Following PE layouts are clumped in order of concurrence.
    ALLOCATED_PEs=0
    #ATM/LND
    TASKS_LND_ROF=756
    ./xmlchange NTASKS_LND=$TASKS_LND_ROF
    ./xmlchange NTASKS_ROF=$TASKS_LND_ROF
    ./xmlchange ROOTPE_LND=$ALLOCATED_PEs       
    ./xmlchange ROOTPE_ROF=$ALLOCATED_PEs
    let ALLOCATED_PEs=ALLOCATED_PEs+TASKS_LND_ROF

    #ICE
    TASKS_ICE=216
    ./xmlchange NTASKS_ICE=$TASKS_ICE
    ./xmlchange ROOTPE_ICE=$ALLOCATED_PEs
    let ALLOCATED_PEs=ALLOCATED_PEs+TASKS_ICE    
    
    #WAV
    TASKS_WAV=36
    ./xmlchange NTASKS_WAV=$TASKS_WAV    
    ./xmlchange ROOTPE_WAV=$ALLOCATED_PEs   
    let ALLOCATED_PEs=ALLOCATED_PEs+TASKS_WAV
       
    #DATM
    TASKS_DATM=36
    ./xmlchange NTASKS_ATM=$TASKS_DATM    
    ./xmlchange ROOTPE_ATM=$ALLOCATED_PEs     
    let ALLOCATED_PEs=ALLOCATED_PEs+TASKS_DATM
    
    #OCN
    TASKS_OCN=1728
         ./xmlchange POP_DECOMPTYPE='cartesian'
	 ./xmlchange POP_AUTO_DECOMP=FALSE
         ./xmlchange POP_MXBLCKS=1
	 ./xmlchange POP_NX_BLOCKS=36
	 ./xmlchange POP_NY_BLOCKS=48
	 ./xmlchange POP_BLCKX=9
	 ./xmlchange POP_BLCKY=8
    ./xmlchange NTASKS_OCN=$TASKS_OCN
    ./xmlchange ROOTPE_OCN=$ALLOCATED_PEs
     
    let ALLOCATED_PEs=ALLOCATED_PEs+TASKS_OCN
    
    #CPL #overlay CPL on LND/ROF, ICE, WAV, and DATM PE columns
    let TASKS_CPL=TASKS_LND_ROF+TASKS_ICE+TASKS_WAV+TASKS_DATM
    ./xmlchange NTASKS_CPL=$TASKS_CPL
    ./xmlchange ROOTPE_CPL=0
    
    #GLC #overlay GLC on top of all other  columns
    let TASKS_GLC=TASKS_LND_ROF+TASKS_ICE+TASKS_WAV+TASKS_DATM+TASKS_OCN
    ./xmlchange NTASKS_GLC=$TASKS_GLC
    ./xmlchange ROOTPE_GLC=0
    
    echo Total of $ALLOCATED_PEs PEs requested fer this simulation...
    ./xmlquery NTASKS
    ./xmlquery ROOTPE    

    ./xmlchange RUNDIR=$JG_t_RunDir
    	 
    ./xmlchange RUN_TYPE='hybrid'
    ./xmlchange RUN_REFCASE="$PreviousBGCaseName"
    ./xmlchange RUN_REFDATE="$BG_Restart_Year"-01-01

    ./xmlchange DATM_MODE='CPLHIST'
    ./xmlchange DATM_CPLHIST_CASE="$PreviousBGCaseName"
    ./xmlchange DATM_CPLHIST_DIR="$BG_tm1_cpl_Dir"
    
    ./xmlchange DATM_CPLHIST_YR_START=$BG_Forcing_Year_Start
    ./xmlchange DATM_CPLHIST_YR_END=$BG_Forcing_Year_End
    ./xmlchange DATM_CPLHIST_YR_ALIGN=$BG_Forcing_Year_Start

    ./xmlchange DATM_PRESAERO='clim_1850'

    ./xmlchange CPL_ALBAV='false'
    ./xmlchange CPL_EPBAL='off'

    ./xmlchange DATM_TOPO='cplhist' #NOTE: ALSO NEED 'a2x3h_S_topo topo' line added to datm/cime_config/namelist_definition_datm.xml!

    ./case.setup
    
###configure archiving
    ./xmlchange DOUT_S=TRUE

###set common user_nl mods that apply to JG and BG alike
     for f in `ls $D/user_nls/user_nl*`; do
         echo Copying $f mods to $CaseName
         cp $f $D/$CaseName
     done
     
### Copy in any SourceMods
     rm -rf  $D/$CaseName/SourceMods
     cp -r $D/SourceMods  $D/$CaseName/SourceMods
     
###configure POP JG-specific settings
cat >> user_nl_pop <<EOF
ladjust_precip=.false.
lsend_precip_fact=.false.
lms_balance=.true.
EOF
   
###configure CISM JG-specific settings
cat >> user_nl_cism <<EOF
ice_tstep_multiply=10
EOF
 
###concatenate monthly forcing files to expected location
    
    for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do 
	for m in `seq -f '%02g' 1 12`; do
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do       
	      fname_out=$BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.$yr-$m.nc
	      if [ ! -f $fname_out ]; then
	         echo 'Concatenating ' $fname_out
	         ncrcat -O $BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc $fname_out &
              fi
	   done
	   wait
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do
	       for fname in $BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc; do 
	           if [ -e "$fname" ]; then
		       echo 'Remove ' $fname
	               rm $fname
                   fi
	       done
	   done	   
	done
    done    
    ftype=ha2x1d
    fname_in=$BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.0001-01-02.nc
    fname_out=$BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.0006-01.nc
    ncks -A -v doma_lat,doma_lon,doma_area,doma_aream,doma_mask,doma_frac $fname_in $fname_out
    for ftype in ha2x1hi ha2x1h ha2x3h; do
    	fname_in=$BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.0001-01-01.nc
    	fname_out=$BG_tm1_cpl_Dir/$PreviousBGCaseName.cpl.$ftype.0006-01.nc
    	ncks -A -v doma_lat,doma_lon,doma_area,doma_aream,doma_mask,doma_frac $fname_in $fname_out
    done

####copy over JG restart files from previous BG run
cp -v $BG_tm1_rest_Dir/* $JG_t_RunDir

###configure submission length, diagnostic CPL history output, and restarting
### final length of JG run should be 150 years
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=15
    ./xmlchange REST_OPTION='nyears'
    ./xmlchange REST_N=5      
    ./xmlchange HIST_OPTION='nyears'
    ./xmlchange HIST_N=1   
    ./xmlchange RESUBMIT=9
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='12:00:00'
    ./xmlchange PROJECT="$ProjCode"

###make some soft links for convenience 
    ln -svf $JG_t_RunDir RunDir
    ln -svf $JG_t_ArchiveDir ArchiveDir 
###set up restoring
    if [ ! -f $BG_tm1_ocn_restoring_Dir/climo_SSS_FLXIO.nc ]; then
       for m in `seq -f '%02g' 1 12`; do
	 echo 'Calculating monthly restoring SSS climatology for month: ' $m
	 flist=""
	 for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do
	   flist="$flist $BG_tm1_ocn_restoring_Dir/$PreviousBGCaseName.pop.h.$yr-$m.nc"
	 done    
	 ncra -F -v SALT -d z_t,1,1,1 $flist $BG_tm1_ocn_restoring_Dir/SSS_FLXIO_$m.nc
	 ncra -A -F -v SALT_F $flist $BG_tm1_ocn_restoring_Dir/SSS_FLXIO_$m.nc
       done

       ncrcat -O $BG_tm1_ocn_restoring_Dir/SSS_FLXIO_* $BG_tm1_ocn_restoring_Dir/temp.nc
       ncrename -v SALT,SSS $BG_tm1_ocn_restoring_Dir/temp.nc
       ncrename -v SALT_F,FLXIO $BG_tm1_ocn_restoring_Dir/temp.nc
       ncwa -O -a z_t $BG_tm1_ocn_restoring_Dir/temp.nc $BG_tm1_ocn_restoring_Dir/climo_SSS_FLXIO.nc
       rm $BG_tm1_ocn_restoring_Dir/SSS_FLXIO_* $BG_tm1_ocn_restoring_Dir/temp.nc

       if [ ! -f $BG_tm1_ocn_restoring_Dir/climo_SSS_FLXIO.nc ]; then
	 echo 'Error: something wrong with climo_SSS_FLXIO.nc creation'
	 exit
       fi
    fi
cat >> user_nl_pop <<EOF   
sfwf_filename='$BG_tm1_ocn_restoring_Dir/climo_SSS_FLXIO.nc'
sfwf_file_fmt='nc'
sfwf_data_type='monthly'
EOF
###build
    ./case.build --clean-all
    ./case.build    

###sumbmit
    ./case.submit --mail-user katec@ucar.edu --mail-type all


    
