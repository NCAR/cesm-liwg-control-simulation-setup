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

#TODO: CHECK SOURCEMODS, CHECK USER NAMELISTS, CHECK RESTART GENERATION

D=$PWD
User=jfyke

    t=1

    BG_CaseName_Root=BG_iteration_

    CaseName=$BG_CaseName_Root"$t"
       
    BG_t_RunDir=/glade/scratch/$User/$CaseName/run

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
    cp $D/env_mach_pes_BG/env_mach_pes_fast.xml $D/$CaseName/env_mach_pes.xml #CHECK THIS!  NOT CLEAR FROM MARCUS INSTRUCTIONS

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

    ./case.setup

    ## Soft-link to initial condition files
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
     #for f in `ls $D/user_nls/user_nl*`; do
     #    echo Copying $f mods to $CaseName
     #    cp  $f $D/$CaseName
     #done

### === CPL, BG-specific output settings === ###
     cat >> user_nl_cpl <<EOF
     histaux_a2x3hr  = .true. 
     histaux_a2x24hr = .true.
     histaux_a2x1hri = .true.
     histaux_a2x1hr  = .true.
EOF

### Copy in any SourceMods
     #cp -rf $D/SourceMods  $D/$CaseName/SourceMods

###configure submission length and restarting

    JOB_QUEUE='economy'
#    JOB_QUEUE='regular'

    ./xmlchange PROJECT="$ProjCode"   

###number of years per submission 
    ## 5 is probably a good compromize
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1

    ./xmlchange RESUBMIT=1
#    ./xmlchange RESUBMIT=34
    ./xmlchange JOB_QUEUE="$JOB_QUEUE"
    ./xmlchange JOB_WALLCLOCK_TIME=01:30:00
#    ./xmlchange JOB_WALLCLOCK_TIME=06:00:00 ## Use for 5yrs submission
#    ./xmlchange --subgroup case.st_archive JOB_QUEUE=regular
#    ./xmlchange --subgroup case.st_archive JOB_WALLCLOCK_TIME=00:02:00

####build
    qcmd -- ./case.build
###submit
    ./case.submit
