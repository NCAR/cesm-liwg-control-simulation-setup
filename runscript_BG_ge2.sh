#!/bin/bash

### === Notes === ###
#
# Setup of first BG segment in the JG/BG
# CESM2-CISM2 spinup simulation.
#
# Setup:
# Compset: B1850G (fully coupled with BGC)
# Start option: (1) hybrid yr 79 from CESM2 spinup
#               (2) ocean tracers from K. Lindsay's spinup
#
# (2) includes namelist and xml options that are turned off 
# in subsequent JG and BG simulations
#
#
# M. Lofverstrom
# NCAR, June 2018
#
#####################

##TODO: CHECK TOPO UPDATER
##TODO: CHECK SOURCEMODS
##TODO: GET MARCUS PE LAYOUT WORKING

D=$PWD
User=jfyke

    t=2
    let tm1=t-1
    
    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_

    BG_Restart_Year=0003
    JG_Restart_Year=0016    

    CaseName=$BG_CaseName_Root"$t"
    PreviousJGCaseName=$JG_CaseName_Root"$t" #Need previous JG iteration to exist, of same iteration number as planned BG
    PreviousBGCaseName="$BG_CaseName_Root""$tm1" #Need previous BG iteration to exist, of n-1 iteration number as planned BG     
      
    BG_t_RunDir=/glade/scratch/$User/$CaseName/run
    JG_t_rest_Dir=/glade/scratch/$User/archive/$PreviousJGCaseName/rest/"$JG_Restart_Year"-01-01-00000/
    BG_tm1_rest_Dir=/glade/scratch/$User/archive/$PreviousBGCaseName/rest/"$BG_Restart_Year"-01-01-00000/
    
###set project code
    ProjCode=P93300301

###set up model
    #Set the source code from which to build model
    CCSMRoot=$D/Model_Version/cesm2.0.0

    echo '****'
    echo "Building code from $CCSMRoot"

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
    #cp $D/env_mach_pes_BG/env_mach_pes_fast.xml $D/$CaseName/env_mach_pes.xml #CHECK THIS!  NOT CLEAR FROM MARCUS INSTRUCTIONS

##set up case    

    ./xmlchange RUN_TYPE='hybrid'
    #Set primary restart-gathering names
    ./xmlchange RUN_REFCASE=$PreviousJGCaseName
    ./xmlchange RUN_REFDATE="$JG_Restart_Year"-01-01  

    ./case.setup

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir   

###enable custom coupler output
    ## Might wanna change this to 'nyears'
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1

###set common user_nl mods that apply to JG and BG alike
     for f in `ls $D/user_nls/user_nl*`; do
         echo Copying $f mods to $CaseName
         cp  $f $D/$CaseName
     done

### === CPL, BG-specific output settings === ###
     cat >> user_nl_cpl <<EOF
     histaux_a2x3hr  = .true. 
     histaux_a2x24hr = .true.
     histaux_a2x1hri = .true.
     histaux_a2x1hr  = .true.
EOF

### Copy in any SourceMods
    rm -rf $D/$CaseName/SourceMods
    cp -r $D/SourceMods  $D/$CaseName/SourceMods

###copy restarts
    # Copy restarts from end of JG simulation
    cp $JG_t_rest_Dir/* . || { echo "copy of JG restarts failed" ; exit 1; }

    #Then copy over CAM restarts from BG
    f=$BG_tm1_rest_Dir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc;  cp -f $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_rest_Dir/$PreviousBGCaseName.cam.rs.$BG_Restart_Year-01-01-00000.nc; cp -f $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_rest_Dir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc;  cp -f $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_rest_Dir/rpointer.atm;                                               cp -f $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  

###set component-specific restarting tweaks that aren't handled by default
    #CAM
    #overwrite default script-generated restart info with custom values, to represent the migrated CAM restart file
     echo "bnd_topo='$BG_t_RunDir/topoDataset.nc'" > user_nl_cam #JER: WHEN TOPO UPDATING WORKING, RUN HERE!
     echo "ncdata='$BG_t_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc'" >> user_nl_cam

###configure topography updating
     CAM_topo_regen_dir=$BG_t_RunDir/dynamic_atm_topog
     module purge
     module load ncarenv/1.2
     module load intel/17.0.1
     module load ncarcompilers/0.4.1
     module load mpt/2.15f
     module load netcdf/4.4.1.1
     if [ ! -d $CAM_topo_regen_dir ]; then
       echo 'Checking out and building topography updater...'

       trunk=https://svn-ccsm-models.cgd.ucar.edu/tools/dynamic_cam_topography/trunk
       svn co --quiet $trunk $CAM_topo_regen_dir
       
       source $CAM_topo_regen_dir/setup.sh --rundir $BG_t_RunDir --project "$ProjCode" --walltime 00:45:00 --queue regular       
       
       cd $CAM_topo_regen_dir/bin_to_cube
       gmake --quiet
       cd $CAM_topo_regen_dir/cube_to_target
       gmake --quiet
 
       cd $D/$CaseName
 
       postrun_script=$CAM_topo_regen_dir/submit_topo_regen_script.sh
       ./xmlchange POSTRUN_SCRIPT=$postrun_script
      fi

#####run dynamic topography interactively update to bring CAM topography up to JG-generated topography before starting
    if [ ! -f $BG_t_RunDir/Temporary_output_file.nc ]; then #Presence of this file signifies an already-run topography updating in this new BG directory...so, skip
       echo 'Submitting an initial topography updating job.  Specified 45 minute sleep of this script will ensue.'
       cd $CAM_topo_regen_dir
       ./submit_topo_regen_script.sh
       cd $D/$CaseName
       sleep 45m
    fi

###configure submission length and restarting

    ./xmlchange PROJECT="$ProjCode"   

###number of years per submission 
    ./xmlchange STOP_OPTION='nyears'
    ###Test layout/wallclock request using default PE layout
    ./xmlchange STOP_N=1
    ./xmlchange JOB_WALLCLOCK_TIME=03:30:00
    ###Production stop_n and wallclock time using Marcus's sped-up PE layout
    #./xmlchange STOP_N=5
    #./xmlchange JOB_WALLCLOCK_TIME=06:00:00

    ./xmlchange RESUBMIT=0
    ./xmlchange JOB_QUEUE='regular'
#    ./xmlchange --subgroup case.st_archive JOB_QUEUE=regular
#    ./xmlchange --subgroup case.st_archive JOB_WALLCLOCK_TIME=00:02:00

####build
    qcmd -- ./case.build
###submit
    ./case.submit
