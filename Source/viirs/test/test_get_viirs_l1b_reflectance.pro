FUNCTION TEST_GET_VIIRS_L1B_REFLECTANCE

  CD, CURRENT=c
  VIIRS_TEST_FILE = c + '/Source/viirs/test/' + 'NPP_VMAE_L1.A2013176.0030.P1_03001.2013176093155.hdf'
  TOA_REFL = GET_VIIRS_L1B_REFLECTANCE(VIIRS_TEST_FILE, 1)
  ;PRINT, TOA_REFL[0,0]
  RETURN, 1
  ;;TODO, WRITE A PROPER TEST HERE 

END
