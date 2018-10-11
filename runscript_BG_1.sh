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

##TODO: CHECK SOURCEMODS
##TODO: GET MARCUS PE LAYOUT WORKING
D=$PWD
User=katec

    t=1

    BG_CaseName_Root=BG_iteration_

    CaseName=$BG_CaseName_Root"$t"
    Outputroot=/glade/scratch/$User/CESM2-CISM2-JG-BG-Sept2018
       
    BG_t_RunDir=$Outputroot/$CaseName/run

###set project code
    ProjCode=P93300301

###set up model
    #Set the source code from which to build model
    CCSMRoot=$D/Model_Version/cesm2.0.1+CISMmaster

    echo '****'
    echo "Building code from $CCSMRoot"

    echo $D/$CaseName

    $CCSMRoot/cime/scripts/create_newcase \
                           --case $D/$CaseName \
	                   --output-root $Outputroot \ 
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
    NTHRDS=1
    PES_PER_NODE=36
    MAX_TASKS_PER_NODE=36

    NTASKS_ATM=50*$PES_PER_NODE
    NTHRDS_ATM=$NTHRDS
    ROOTPE_ATM=0

    NTASKS_GLC=$NTASKS_ATM
    NTHRDS_GLC=$NTHRDS
    ROOTPE_GLC=0

    NTASKS_LND=39*$PES_PER_NODE
    NTHRDS_LND=$NTHRDS
    ROOTPE_LND=0

    NTASKS_ROF=$NTASKS_LND
    NTHRDS_ROF=$NTHRDS
    ROOTPE_ROF=$ROOTPE_LND

    NTASKS_ICE=10*$PES_PER_NODE
    NTHRDS_ICE=$NTHRDS
    ROOTPE_ICE=$NTASKS_LND

    NTASKS_CPL=$NTASKS_ICE
    NTHRDS_CPL=$NTHRDS
    ROOTPE_CPL=$NTASKS_LND

    NTASKS_WAV=1*$PES_PER_NODE
    NTHRDS_WAV=$NTHRDS
    ROOTPE_WAV=$NTASKS_LND+$NTASKS_ICE

    NTASKS_OCN=10*$PES_PER_NODE
    NTHRDS_OCN=$NTHRDS
    ROOTPE_OCN=$NTASKS_ATM
    
    ./xmlchange NTASKS_ATM=$NTASKS_ATM
    ./xmlchange NTHRDS_ATM=$NTHRDS_ATM
    ./xmlchange ROOTPE_ATM=$ROOTPE_ATM

    ./xmlchange NTASKS_GLC=$NTASKS_GLC
    ./xmlchange NTHRDS_GLC=$NTHRDS_GLC
    ./xmlchange ROOTPE_GLC=$ROOTPE_GLC

    ./xmlchange NTASKS_LND=$NTASKS_LND
    ./xmlchange NTHRDS_LND=$NTHRDS_LND
    ./xmlchange ROOTPE_LND=$ROOTPE_LND

    ./xmlchange NTASKS_ROF=$NTASKS_ROF
    ./xmlchange NTHRDS_ROF=$NTHRDS_ROF
    ./xmlchange ROOTPE_ROF=$ROOTPE_ROF

    ./xmlchange NTASKS_ICE=$NTASKS_ICE
    ./xmlchange NTHRDS_ICE=$NTHRDS_ICE
    ./xmlchange ROOTPE_ICE=$ROOTPE_ICE

    ./xmlchange NTASKS_CPL=$NTASKS_CPL
    ./xmlchange NTHRDS_CPL=$NTHRDS_CPL
    ./xmlchange ROOTPE_CPL=$ROOTPE_CPL

    ./xmlchange NTASKS_WAV=$NTASKS_WAV
    ./xmlchange NTHRDS_WAV=$NTHRDS_WAV
    ./xmlchange ROOTPE_WAV=$ROOTPE_WAV

    ./xmlchange NTASKS_OCN=$NTASKS_OCN
    ./xmlchange NTHRDS_OCN=$NTHRDS_OCN
    ./xmlchange ROOTPE_OCN=$ROOTPE_OCN

    ./xmlchange PES_PER_NODE=$PES_PER_NODE
    ./xmlchange MAX_TASKS_PER_NODE=$MAX_TASKS_PER_NODE

##set up case    

    ./xmlchange RUN_TYPE='hybrid'
    #Set primary restart-gathering names
    ./xmlchange RUN_REFDIR=$BG_t_RunDir
    ./xmlchange RUN_REFCASE=b.e20.B1850.f09_g17.pi_control.all.297.clone
    ./xmlchange RUN_REFDATE=0078-01-01
    ./xmlchange RUN_STARTDATE=0001-01-01
    ./xmlchange CONTINUE_RUN=FALSE

    # Set ocean tracers from separate file
    ## === OBS === Only in BG1, uncomment for all other simulations
    ./xmlchange POP_PASSIVE_TRACER_RESTART_OVERRIDE='/glade/scratch/klindsay/archive/g.e20e10j.G1850ECO_CPLHIST.f09_g17.bf_spin.001/rest/1597-01-01-00000/g.e20e10j.G1850ECO_CPLHIST.f09_g17.bf_spin.001.pop.r.1597-01-01-00000.nc'

    if [ $t == 2 ]; then
	./xmlchange POP_PASSIVE_TRACER_RESTART_OVERRIDE='none'
    fi

#    ./case.setup
    ./case.setup --reset

    ## Copy  to initial condition files
    CESM_SD="/glade/u/home/marcusl/liwg/JG_BG_setup_and_initial_conditions/BG1_initial_conditions/CESM2_rest/0078-01-01-00000"
    CESM_CaseName="b.e20.B1850.f09_g17.pi_control.all.297.clone"

    for f in `ls "$CESM_SD"/"$CESM_CaseName"*`; do
      if ! echo $f | grep --quiet 'cism.r.'; then
         echo Copying $f
         cp $f $BG_t_RunDir/`basename $f`
      fi
    done

    for f in rpointer.atm \
             rpointer.drv \
	     rpointer.ice \
	     rpointer.lnd \
	     rpointer.ocn.ovf \
	     rpointer.ocn.restart \
	     rpointer.rof; do
      cp $CESM_SD/$f $BG_t_RunDir/$f
    done

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
    ./xmlchange JOB_QUEUE='economy'
#    ./xmlchange --subgroup case.st_archive JOB_QUEUE=regular
#    ./xmlchange --subgroup case.st_archive JOB_WALLCLOCK_TIME=00:02:00

####build
    qcmd -- ./case.build
###submit
    ./case.submit
