PRO TEST_VIIRS_L1B_EMMISIVE

; LIKE A UNIT TEST FOR GET_VIIRS_LAT_LON

; READ IN THE TEST FILE AND PRINT THE LAT AND LON TO THE SCREEN
;/home/marrabld/projects/DIMITRI_2.0/Source/viirs/test
CD, CURRENT=c
VIIRS_TEST_FILE = c + '/Source/viirs/test/' + 'NPP_VMAE_L1.A2013176.0030.P1_03001.2013176093155.hdf'
TOA_EMM = GET_VIIRS_L1B_EMISSIVE(VIIRS_TEST_FILE)
PRINT, TOA_EMM[0,0,0]

END