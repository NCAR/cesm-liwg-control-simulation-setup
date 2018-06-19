#!/bin/bash

### === Notes === ###
#
# Setup of BG segment 2-8 in the JG/BG
# CESM2-CISM2 spinup simulation.
#
# Setup:
# Compset: B1850G (fully coupled with BGC)
# Start option: hybrid from previous BG and JG case
#
#
# M. Lofverstrom
# NCAR, June 2018
#
#####################

D=$PWD

    t=2
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_

    BG_Restart_Year=0001
    JG_Restart_Year=0001

    CaseName=$BG_CaseName_Root"$t"
    PreviousJGCaseName=$JG_CaseName_Root"$t" #Need previous JG iteration to exist, of same iteration number as planned BG
    PreviousBGCaseName="$BG_CaseName_Root""$tm1" #Need previous BG iteration to exist, of n-1 iteration number as planned BG
       
    BG_t_RunDir=/glade/scratch/marcusl/$CaseName/run
    JG_t_RunDir=/glade/scratch/marcusl/$PreviousJGCaseName/run
    BG_tm1_RunDir=/glade/scratch/marcusl/$PreviousBGCaseName/run

###set project code
#    ProjCode=P93300324
#    ProjCode=P93300624
    ProjCode=P93300601
#    ProjCode=P93300301

###set up model
    #Set the source code from which to build model
#    CCSMRoot=/glade/p/work/marcusl/CESM_model_versions/cesm2_0_exp10j
    CCSMRoot=/glade/u/home/marcusl/work/CESM_model_versions/cesm2_0_beta10

    echo '****'
    echo "Building code from $CCSMRoot with source code modifications in following files:"
    svn status $CCSMRoot | grep 'M    '
    echo '****'
#    exit


    echo $D/$CaseName

    $CCSMRoot/cime/scripts/create_newcase \
                           --case $D/$CaseName \
                           --compset B1850G \
                           --res f09_g17_gl4 \
                           --mach cheyenne \
                           --project $ProjCode \
                           --run-unsupported 


    #Change directories into the new experiment case directory
    cd $D/$CaseName


###customize PE layout
    ## Copy env_mach_pes.xml from "official spinup"
    $cp $D/env_mach_pes_BG/env_mach_pes.xml $D/$CaseName/



###copy sourcemods
#/bin/cp /glade/p/cesmdata/cseg/runs/cesm2_0/b.e20.B1850.f09_g16.pi_control.all.143/SourceMods/src.pop/*   SourceMods/src.pop
#/bin/cp /glade/p/cesmdata/cseg/runs/cesm2_0/b.e20.B1850.f09_g16.pi_control.all.143/SourceMods/src.cam/*   SourceMods/src.cam
#/bin/cp /glade/p/cesmdata/cseg/runs/cesm2_0/b.e20.B1850.f09_g16.pi_control.all.143/SourceMods/src.clm/*   SourceMods/src.clm
#/bin/cp /glade/u/home/klindsay/fixes/qflux_robert/133-143/* SourceMods/src.pop
#cp /glade/scratch/dbailey/b.e20.BHIST.f09_g16.20thC.144_01/SourceMods/src.cice/*  SourceMods/src.cice


###set up case    
    ./xmlchange RUN_REFCASE=$PreviousJGCaseName
    ./xmlchange RUN_REFDATE="$JG_Restart_Year"-01-01

    ./xmlchange RUN_TYPE='hybrid'


    # Use ocean tracers from separate file
    ./xmlchange POP_PASSIVE_TRACER_RESTART_OVERRIDE='none'


    ./case.setup

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir   

###enable custom coupler output
    ## Might wanna change this to 'nyears'
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1



###configure topography updating
     CAM_topo_regen_dir=$BG_t_RunDir/dynamic_atm_topog
     
     # module loads
     module purge
     module load ncarenv/1.2
     module load intel/17.0.1
     module load ncarcompilers/0.4.1
     module load mpt/2.15f

     module load netcdf/4.4.1.1
     module load nco/4.6.2
     module load python/2.7.13     
     
#     if [ ! -d $CAM_topo_regen_dir ]; then
#       echo 'Checking out and building topography updater...'

#       trunk=https://svn-ccsm-models.cgd.ucar.edu/tools/dynamic_cam_topography/trunk
#       svn co --quiet $trunk $CAM_topo_regen_dir
       
#       source $CAM_topo_regen_dir/setup.sh --rundir $BG_t_RunDir --project "$ProjCode" --walltime 00:45:00 --queue regular       
       
#       cd $CAM_topo_regen_dir/bin_to_cube
#       gmake --quiet
#       cd $CAM_topo_regen_dir/cube_to_target
#       gmake --quiet
# 
#       cd $D/$CaseName
 
#       postrun_script=$CAM_topo_regen_dir/submit_topo_regen_script.sh
#       ./xmlchange POSTRUN_SCRIPT=$postrun_script

#       data_assimilation_script=$CAM_topo_regen_dir/submit_topo_regen_script.sh
#       ./xmlchange DATA_ASSIMILATION=TRUE
#       ./xmlchange DATA_ASSIMILATION_CYCLES=1
#       ./xmlchange DATA_ASSIMILATION_SCRIPT=$data_assimilation_script

#      fi       

###configure archiving
#    ./xmlchange DOUT_S=FALSE



###copy all but CAM restarts over from end of JG simulation, and CAM restarts from previous BG simulation
    
    f=$JG_t_RunDir/$PreviousJGCaseName.cice.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.cism.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.clm2.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.clm2.rh0."$JG_Restart_Year"-01-01-00000.nc;    cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.cpl.hi."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$JG_t_RunDir/$PreviousJGCaseName.cpl.r."$JG_Restart_Year"-01-01-00000.nc;       cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.datm.rs1."$JG_Restart_Year"-01-01-00000.bin;   cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.mosart.r."$JG_Restart_Year"-01-01-00000.nc;    cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$JG_t_RunDir/$PreviousJGCaseName.mosart.rh0."$JG_Restart_Year"-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }     
    f=$JG_t_RunDir/$PreviousJGCaseName.pop.r."$JG_Restart_Year"-01-01-00000.nc;       cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.pop.ro."$JG_Restart_Year"-01-01-00000;         cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }        
    f=$JG_t_RunDir/rpointer.drv;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.glc;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ice;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.lnd;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ocn.ovf;                                                  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ocn.restart;                                              cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.rof;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }

    #Ensure dates of non-CAM restart pointers are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$JG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.*

    #Then copy over CAM restarts
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.rs.$BG_Restart_Year-01-01-00000.nc; cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/rpointer.atm;                                               cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  


###set component-specific restarting tweaks that aren't handled by default

### === CAM === ###
#overwrite default script-generated restart info with custom values, to represent the migrated CAM restart file

cat > user_nl_cam <<EOF
 nhtfrq = 0,-8760
 empty_htapes = .true.

 fincl1 = 'FLDS', 'FLNS', 'FLNSC', 'FLNT', 'FLNTC', 'FLUT', 'FLUTC', 
 'FSDS', 'FSDSC', 'FSNS', 'FSNSC', 'FSNT', 'FSNTC', 'FSNTOA', 'FSNTOAC', 'FSUTOA', 
 'PRECC', 'PRECL', 'PRECSC', 'PRECSL', 'TMQ', 'TS', 'PSL',
 'CLDHGH', 'CLDLOW', 'CLDMED', 'CLDTOT', 'SHFLX', 'LHFLX', 'ICEFRAC', 
 'SNOWHLND', 'SNOWHICE', 'TAUX', 'TAUY', 'TGCLDCWP', 'TGCLDIWP', 'TGCLDLWP',
 'U250', 'U500', 'U850', 'V250', 'V500', 'V850'

 fincl2 = 
 'FLDS', 'FLNS', 'FLNSC', 'FLNT', 'FLNTC', 'FLUT', 'FLUTC', 
 'FSDS', 'FSDSC', 'FSNS', 'FSNSC', 'FSNT', 'FSNTC', 'FSNTOA', 'FSNTOAC', 'FSUTOA', 
 'ICEFRAC', 'LANDFRAC', 'LHFLX', 'LWCF', 'OCNFRAC', 'PBLH', 'PHIS', 
 'PRECC', 'PRECL', 'PRECSC', 'PRECSL', 'PS', 'PSL', 'QFLX', 'QREFHT', 'SHFLX', 
 'SOLIN', 'TREFHT', 'TS', 'TSMN', 'TSMX', 'U10', 'SWCF', 
 'CLDICE', 'CLDLIQ', 'CLOUD', 'OMEGA', 'Q', 
 'RELHUM', 'T', 'Z3', 'V', 'U', 'UU', 'VV', 'VU'

 ncdata='$BG_t_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc'
 bnd_topo='$BG_t_RunDir/topoDataset.nc'

EOF



### === CLM === ###
##hist_nhtfrq=-8760,0 ## (-24*365), 0 # OBS, neg means hr, 0 = monthly
##hist_fexcl1 = '' ## Exclude variables from htape 1


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


### === CISM === ###

## Pseudo plastic settings recommended by Sarah Bradley, 
## approved by W. Lipscomb

cat > user_nl_cism <<EOF
 temp_init = 4
 pseudo_plastic_bedmax = 700.
 pseudo_plastic_bedmin = -300.
 cesm_history_vars='acab_applied artm beta_internal bmlt bmlt_applied bpmp bwat calving_rate floating_mask grounded_mask smb tempstag thk topg uvel vvel wvel velnorm ubas vbas ivol iareag iareaf iarea imass imass_above_flotation'
EOF


### === CPL === ###
cat > user_nl_cpl <<EOF
 histaux_a2x3hr  = .true. 
 histaux_a2x24hr = .true.
 histaux_a2x1hri = .true.
 histaux_a2x1hr  = .true.
EOF



### === MARBL === ###

## K. Lindsay's user_nl_marbl

# ladjust_bury_coeff=.true.
#!init_bury_coeff_opt='settings_file'
#
# grazing(2,1)%z_umax_0_per_day = 3.15
# grazing(3,1)%z_umax_0_per_day = 3.3
#
# autotrophs(3)%PCref_per_day = 2.5
#
# parm_FeLig_scavenge_rate0 = 1.3
# parm_Fe_scavenge_rate0 = 24
#
# autotrophs(1)%gQfe_min = 2.7e-06
# autotrophs(2)%gQfe_min = 2.7e-06
# autotrophs(3)%gQfe_min = 5.4e-06
#
# parm_scalelen_vals(1) = 1
# parm_scalelen_vals(2) = 2.9
# parm_scalelen_vals(3) = 4.5
# parm_scalelen_vals(4) = 5.0

# parm_SiO2_diss = 700.0e2

# caco3_bury_thres_omega_calc = 0.90



## OBS: these parameter settings may be
##      changed before the POP BGC spinup
##      is done. Check with K. Lindsay...

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


### === POP === ###

## K. Lindsay's user_nl_pop
#
# lsend_precip_fact = .true.
# precip_fact_const = 0.99791
# chl_option = 'model'
# moc_requested = .false.
# n_heat_trans_requested = .false.
# n_salt_trans_requested = .false.
# ldiag_bsf = .false.
# diag_gm_bolus = .false.

# n_tavg_streams = 1
# ltavg_ignore_extra_streams = .true.
# tavg_freq_opt(1) = 'nyear'
# tavg_file_freq_opt(1) = 'nyear'

#!init_ecosys_option = 'file'
#!init_ecosys_init_file = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/ic/ecosys_jan_IC_gx1v6_20180308.nc'

# fesedflux_input%filename = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/forcing/fesedfluxTot_gx1v6_cesm2_2018_c180507.nc'

# nhy_flux_monthly_input%filename = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/forcing/ndep_ocn_1850_w_nhx_emis_gx1v6_c180427.nc'
# nox_flux_monthly_input%filename = '/glade/p/cesmdata/cseg/inputdata/ocn/pop/gx1v6/forcigg/ndep_ocn_1850_w_nhx_emis_gx1v6_c180427.nc'


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
EOF



### === WW === ###
cat > user_nl_ww <<EOF
EOF



### === CICE === ###
cat > user_nl_cice <<EOF
 histfreq = "y"
 histfreq_n = 1
EOF








#Jer: if Marcus's updates to topography updater work, then the following lines can be removed.
    #for a hybrid run, tack on landm_coslat, landfrac to cam.r. (since this is being used as the topography file)
#    DataSourceFile=/glade/p/cesmdata/cseg/inputdata/atm/cam/topo/fv_0.9x1.25_nc3000_Nsw042_Nrs008_Co060_Fi001_ZR_sgh30_24km_GRNL_c170103.nc
#    ncks -A -v LANDM_COSLAT,LANDFRAC,\
#TERR_UF,\
#SGH_UF,\
#GBXAR,\
#MXDIS,\
#RISEQ,\
#FALLQ,\
#MXVRX,\
#MXVRY,\
#ANGLL,\
#ANGLX,\
#ANISO,\
#ANIXY,\
#HWDTH,\
#WGHTS,\
#CLNGT,\
#CWGHT,\
#COUNT $DataSourceFile $BG_t_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc
	
    #Ensure dates are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$BG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.atm
    
###configure submission length and restarting
#
# Comment: run 5 years per submission?
#

    JOB_QUEUE='economy'
#    JOB_QUEUE='regular'

    ./xmlchange PROJECT="$ProjCode"   

#    ./xmlchange STOP_OPTION='nyears'
#    ./xmlchange STOP_N=1


###number of years per submission 
    ## 5 is probably a good compromize
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=5

###restart files every # years
    ## use 5 for BG (sync with STOP_N)
    ./xmlchange REST_OPTION='nyears'
    ./xmlchange REST_N=5


    ./xmlchange RESUBMIT=6
#    ./xmlchange RESUBMIT=34
    ./xmlchange JOB_QUEUE="$JOB_QUEUE"
#    ./xmlchange JOB_WALLCLOCK_TIME=01:30:00
    ./xmlchange JOB_WALLCLOCK_TIME=05:30:00 ## Use for sim (5yrs per submission)
#    ./xmlchange JOB_WALLCLOCK_TIME=02:40:00 ## 
#    ./xmlchange JOB_WALLCLOCK_TIME=00:10:00
    ./xmlchange --subgroup case.st_archive JOB_QUEUE=regular
    ./xmlchange --subgroup case.st_archive JOB_WALLCLOCK_TIME=00:05:00

#####run dynamic topography interactively update to bring CAM topography up to JG-generated topography before starting
#    if [ ! -f $BG_t_RunDir/Temporary_output_file.nc ]; then #Presence of this file signifies an already-run topography updating in this new BG directory...so, skip
#       echo 'Submitting an initial topography updating job.  Specified 45 minute sleep of this script will ensue.'
#       cd $CAM_topo_regen_dir
#       ./submit_topo_regen_script.sh
#       cd $D/$CaseName
#       sleep 45m
#    fi

####build
#    qcmd -- ./case.build
####submit
#    ./case.submit


#END
