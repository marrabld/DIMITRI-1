function TEST_GET_VIIRS_EMISSIVE_BTEMP

CD, CURRENT=c
VIIRS_TEST_FILE = c + '/Source/viirs/test/' + 'NPP_VMAE_L1.A2013176.0030.P1_03001.2013176093155.hdf'
BTEMP = GET_VIIRS_EMISSIVE_BTEMP(VIIRS_TEST_FILE)
;PRINT, BTEMP[0,0,0]
;; Todo, write a better test.
return, 1
END