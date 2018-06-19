#!/bin/bash

D=$PWD

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=2
    let tm1=t-1

    BG_CaseName_Root=test_sourcemods_BG_iteration_
    JG_CaseName_Root=test_sourcemods_JG_iteration_
    BG_Restart_Year_Short=35
    BG_Restart_Year=`printf %04d $BG_Restart_Year_Short`
    BG_Forcing_Year_Start=5
    let BG_Forcing_Year_End=BG_Restart_Year_Short-1
    
    #Set name of simulation
    CaseName=$JG_CaseName_Root"$t"
    PreviousBGCaseName="$BG_CaseName_Root""$tm1"
    JG_t_RunDir=/glade/scratch/marcusl/$CaseName/run
    BG_tm1_ArchiveDir=/glade/scratch/marcusl/$PreviousBGCaseName/run

###set project code
    ProjCode=P93300301
#    ProjCode=P93300601

###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/p/work/marcusl/CESM_model_versions/cesm2_0_beta10


    echo '****'
    echo "Building code from $CCSMRoot with source code modifications in following files:"
    svn status $CCSMRoot | grep 'M    '
    echo '****'    


#			   --user-compset \
    
    $CCSMRoot/cime/scripts/create_newcase \
                           --case $D/$CaseName \
			   --compset 1850_DATM%CRU_CLM50%BGC_CICE_POP2%ECO_MOSART_CISM2%EVOLVE_WW3_BGC%BDRD \
			   --res f09_g17_gl4 \
			   --mach cheyenne \
			   --project $ProjCode \
			   --run-unsupported 
			   
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
#    ./xmlchange DATM_MODE='CPLHISTForcing' ## not working..
    ./xmlchange DATM_CPLHIST_CASE="$PreviousBGCaseName"
    ./xmlchange DATM_CPLHIST_DIR="$BG_tm1_ArchiveDir"
    
    ./xmlchange DATM_CPLHIST_YR_START=$BG_Forcing_Year_Start
    ./xmlchange DATM_CPLHIST_YR_END=$BG_Forcing_Year_End
    ./xmlchange DATM_CPLHIST_YR_ALIGN=$BG_Forcing_Year_Start

#    ./xmlchange DATM_PRESAERO='cplhist' ## not working
    ./xmlchange DATM_PRESAERO='clim_1850'



    ./xmlchange CPL_ALBAV='false'
    ./xmlchange CPL_EPBAL='off'

#    ./xmlchange DATM_TOPO='none' #NOTE: ALSO NEED 'a2x3h_S_topo topo' line added to datm/cime_config/namelist_definition_datm.xml!
    ./xmlchange DATM_TOPO='cplhist' #NOTE: ALSO NEED 'a2x3h_S_topo topo' line added to datm/cime_config/namelist_definition_datm.xml!

    ./case.setup
    
###configure archiving
    ./xmlchange DOUT_S=FALSE




###configure CICE
cat > user_nl_cice <<EOF
 histfreq = "y"
 histfreq_n = 1
EOF


###configure CLM 
cat > user_nl_clm <<EOF
 hist_empty_htapes = .true.
 hist_fincl1 = 'EFLX_LH_TOT', 'FIRA', 'FIRA_R', 'FIRE', 'FIRE_R', 'FLDS', 'FSA', 'FSDS',
 'FSH', 'FSM', 'QICE', 'QICE_FRZ', 'QICE_MELT',
 'QRUNOFF', 'QRUNOFF_ICE', 'QRUNOFF_ICE_TO_COUPLER', 'QRUNOFF_TO_COUPLER', 'QSNOCPLIQ',
 'QSNOEVAP', 'QSNOFRZ', 'QSNOFRZ_ICE', 'QSNOMELT', 'QSNOMELT_ICE',
 'QSNO_TEMPUNLOAD', 'QSNO_WINDUNLOAD', 'QSNWCPICE', 'QSOIL', 'QSOIL_ICE',
 'QVEGE', 'QVEGT', 'RAIN', 'RAIN_FROM_ATM','SNOW', 'SNOWDP', 'SNOWICE', 'SNOWLIQ',
 'SNOW_DEPTH', 'SNOW_FROM_ATM', 'SNOW_PERSISTENCE', 'SNOW_SINKS', 'SNOW_SOURCES',
 'SOIL1C', 'SOIL1N', 'SOIL2C', 'SOIL2N', 'SOIL3C', 'SOIL3N', 'TSA', 'TBOT',
 'TOTECOSYSC','TOTECOSYSN','TOTSOMC','TOTSOMN','TOTVEGC','TOTVEGN','TLAI',
 'GPP','CPOOL','NPP','TWS'
EOF

    
###configure CISM2    
cat > user_nl_cism <<EOF
 temp_init = 4
 pseudo_plastic_bedmax = 700.
 pseudo_plastic_bedmin = -300.
 cesm_history_vars='acab_applied artm beta_internal bmlt bmlt_applied bpmp bwat calving_rate floating_mask grounded_mask smb tempstag thk topg uvel vvel wvel velnorm ubas vbas ivol iareag iareaf iarea imass imass_above_flotation'
 ice_tstep_multiply=10
EOF



### configure marbl
## OBS: these settings might change -- talk to K Lindsay
cat > user_nl_marbl <<EOF
 ladjust_bury_coeff=.false.

 grazing(2,1)%z_umax_0_per_day = 3.15
 grazing(3,1)%z_umax_0_per_day = 3.3

 autotrophs(3)%PCref_per_day = 2.5

 parm_FeLig_scavenge_rate0 = 1.3
 parm_Fe_scavenge_rate0 = 24

 autotrophs(1)%gQfe_min = 2.7e-06
 autotrophs(2)%gQfe_min = 2.7e-06
 autotrophs(3)%gQfe_min = 5.4e-06

 parm_scalelen_vals(1) = 1
 parm_scalelen_vals(2) = 2.9
 parm_scalelen_vals(3) = 4.5
 parm_scalelen_vals(4) = 5.0

 parm_SiO2_diss = 700.0e2

 caco3_bury_thres_omega_calc = 0.90
EOF

    
###configure POP
## OBS: these settings might change -- talk to K Lindsay
cat > user_nl_pop <<EOF
 chl_option = 'model'
 n_tavg_streams = 1
 ltavg_ignore_extra_streams = .true.
 tavg_freq_opt(1) = 'nyear'
 tavg_file_freq_opt(1) = 'nyear'
 tavg_contents = '/glade/p/cesm/liwg/JG_BG_setup_and_initial_conditions/POP_output_list/gx1v7_tavg_contents'


 fesedflux_input%filename = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/forcing/fesedfluxTot_gx1v6_cesm2_2018_c180507.nc'

 nhy_flux_monthly_input%filename = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/forcing/ndep_ocn_1850_w_nhx_emis_gx1v6_c180427.nc'
 nox_flux_monthly_input%filename = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/forcing/ndep_ocn_1850_w_nhx_emis_gx1v6_c180427.nc'

ladjust_precip=.false.
lsend_precip_fact=.false.
lms_balance=.true.

EOF



    #Turn off precipitation scaling in POP for JG runs
#    echo ladjust_precip=.false. > user_nl_pop
#    echo lsend_precip_fact=.false. >> user_nl_pop
    #Turn on inland sea->open ocean rebalancing (should reduce amount of restoring in these regions)
#    echo lms_balance=.true. >> user_nl_pop 
    
###concatenate monthly forcing files to expected location
    
    for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do 
	for m in `seq -f '%02g' 1 12`; do
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do       
	      fname_out=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m.nc
	      if [ ! -f $fname_out ]; then
	         echo 'Concatenating ' $fname_out
	         ncrcat -O $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc $fname_out &
              fi
	   done
	   wait
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do
	       for fname in $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc; do 
	           if [ -e "$fname" ]; then
	               rm -v $fname
                   fi
	       done
	   done	   
	done
    done    

####copy over JG restart files from previous BG run
    echo Copying restart files from $PreviousBGCaseName
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cice.r."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cism.r."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.clm2.r."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.clm2.rh0."$BG_Restart_Year"-01-01-00000.nc;    cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.hi."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.r."$BG_Restart_Year"-01-01-00000.nc;       cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.mosart.r."$BG_Restart_Year"-01-01-00000.nc;    cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.mosart.rh0."$BG_Restart_Year"-01-01-00000.nc;  cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }     
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.r."$BG_Restart_Year"-01-01-00000.nc;       cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.ro."$BG_Restart_Year"-01-01-00000;         cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }        
    f=$BG_tm1_ArchiveDir/rpointer.drv;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.glc;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.ice;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.lnd;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.ocn.ovf;                                                  cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.ocn.restart;                                              cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.rof;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  
    #Ensure dates are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$BG_Restart_Year"-01-01-00000/g" "$JG_t_RunDir"/rpointer.*

###configure submission length, diagnostic CPL history output, and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=15
    ./xmlchange REST_OPTION='nyears'
    ./xmlchange REST_N=5      
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1   
    ./xmlchange RESUBMIT=9
#    ./xmlchange JOB_QUEUE='economy'
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='12:00:00'
    ./xmlchange PROJECT="$ProjCode"


###make some soft links for convenience 
    ln -svf $JG_t_RunDir RunDir
#    ln -svf /glade/scratch/jfyke/archive/$CaseName ArchiveDir
    ln -svf /glade/scratch/marcusl/archive/$CaseName ArchiveDir
    
###set up restoring
    if [ ! -f $BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc ]; then
       for m in `seq -f '%02g' 1 12`; do
	 echo 'Calculating monthly restoring SSS climatology for month: ' $m
	 flist=""
	 for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do
	   flist="$flist $BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.h.$yr-$m.nc"
	 done    
	 ncra -F -v SALT -d z_t,1,1,1 $flist $BG_tm1_ArchiveDir/SSS_FLXIO_$m.nc
	 ncra -A -F -v SALT_F $flist $BG_tm1_ArchiveDir/SSS_FLXIO_$m.nc
       done

       ncrcat -O $BG_tm1_ArchiveDir/SSS_FLXIO_* $BG_tm1_ArchiveDir/temp.nc
       ncrename -v SALT,SSS $BG_tm1_ArchiveDir/temp.nc
       ncrename -v SALT_F,FLXIO $BG_tm1_ArchiveDir/temp.nc
       ncwa -O -a z_t $BG_tm1_ArchiveDir/temp.nc $BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc
       rm $BG_tm1_ArchiveDir/SSS_FLXIO_* $BG_tm1_ArchiveDir/temp.nc

       if [ ! -f $BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc ]; then
	 echo 'Error: something wrong with climo_SSS_FLXIO.nc creation'
	 exit
       fi
    fi
    
    echo "sfwf_filename='$BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc'" >> user_nl_pop
    echo "sfwf_file_fmt='nc'" >> user_nl_pop
    echo "sfwf_data_type='monthly'" >> user_nl_pop



    
###build
#    ./case.build    

###sumbmit
#    ./case.submit


    
