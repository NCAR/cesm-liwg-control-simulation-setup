# cesm-liwg-control-simulation-setup
Scripts and settings used for the CESM Land Ice Working Group JG-BG spinup

# Diagostic plots available at:
https://drive.google.com/drive/u/1/folders/12JlbJGXDewBOZeCyXCKBFLjG0D4b8AkW

# Generation of the CISM ‘RELX’ field added to the input data set:
To run CISM with isostasy: elastic lithosphere and relaxed asthenosphere, option whichrelaxed=0 requires in the input file a RELX field. The RELX field can be interpreted as the topography that would be reached, when the asthenosphere fully relaxed. More information on the differences is given in 
		~/source_cism/libglide/isostasy.F90

In the cisminputfile: greenland_4km_epsg3413_c171126_10ka_temp_relx.nc - RELX field was generated as follows:

Using CISM60 - ran a 30ka standalone simulation, using the same config settings as defined in user_nl_cism, forced with an acab from an earlier CESM simulation, but with whichrelaxed=2.

The RELX field is generated using the simulated topg and load fields at 30 ka:
	RELX = topg(30ka) + load (30ka)
 
- CESM -acab field:
	- BHIST run,#261 (with the bug fixes in CLM between 289-291)
	- SMB definition which includes changes in the snowpack
	- acab field was averaged between 1960-1980
	- CLM - no repartition; h2osn_max=1000m; no LW downscaling

 
-


