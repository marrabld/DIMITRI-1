;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      DIMITRI_VISUALISATION_SUPER_RHO     
;* 
;* PURPOSE:
;*      THIS PROGRAM AUTOMATICALLY SERACHES AND RETRIEVES THE CONCATENATED SUPER SENSOR RHO VALUES 
;*      OUTPUT BY DIMITRI GIVEN AN OUTPUT FOLDER AND REFERENCE SENSOR BAND.
;* 
;* CALLING SEQUENCE:
;*      RES = DIMITRI_VISUALISATION_SUPER_RHO(RC_FOLDER,RC_REGION,REF_SENSOR,REF_PROC_VER,DIMITRI_BAND)      
;*
;* INPUTS:
;*      rc_FOLDER     - A STRING OF THE FULL PATH FOR THE RECALIBRATION OUTPUT FOLDER
;*      RC_REGION     - A STRING OF THE DIMITRI VALIDATION SITE REQUESTED
;*      REF_SENSOR    - A STRING OF THE REFERENCE SENSOR 
;*      REF_PROC_VER  - A STRING OF THE REFERENCE SENSORS PROCESSING VERSION
;*      DIMITRI_BAND  - AN INTEGER OF THE DIMITRI BAND INDEX
;*
;* KEYWORDS:
;*      VERBOSE - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      A STRUCTURE WITH THE FOLLOWING TAGS:
;*      ERROR             - THE ERROR STATUS CODE, 0 = NOMINAL, 1 OR -1 = ERROR
;*      SS_DATA           - AN ARRAY CONTAINING THE SUPER SENSOR REFLECTANCE AND TIME
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*      19 MAY 2011 - C KENT    - DIMITRI-2 V1.0
;*      04 JUL 2011 - C KENT    - UPDATED NUM OF NON REFLECTANCE VARIABLE
;*	05 AUG 2011 - C KENT	- ADDED MODISA SITE EXCEPTION
;*
;* VALIDATION HISTORY:
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION DIMITRI_VISUALISATION_SUPER_RHO,RC_FOLDER,RC_REGION,REF_SENSOR,REF_PROC_VER,DIMITRI_BAND,VERBOSE=VERBOSE

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DIMITRI_VISU_SUPER: STARTING RETRIEVAL OF DATA'
  RAISE_NO_SDATA = 1
  NUM_NON_REF = 5+12 ;(TIME, ANGLES (4) AND AUX INFO (12)

;-----------------------------------------
; RETRIEVE THE SITE TYPE

  SITE_TYPE = GET_SITE_TYPE(RC_REGION,VERBOSE=VERBOSE)

;-----------------------------------------
; ADD MODIS LAND/OCEAN EXCEPTION
      
  IF REF_SENSOR EQ 'MODISA' THEN BEGIN
    IF STRUPCASE(SITE_TYPE) EQ 'OCEAN' THEN TEMP_SENSOR1 = REF_SENSOR+'_O' ELSE TEMP_SENSOR1 = REF_SENSOR+'_L'
  ENDIF ELSE TEMP_SENSOR1 = REF_SENSOR

;-------------------------------- 
; FIND SUPER SENSOR DAT FILE AND RESTORE IF AVAILABLE
  
  RES = GET_SENSOR_BAND_INDEX(TEMP_SENSOR1,DIMITRI_BAND)
  IF RES[0] LT 0 THEN GOTO, SSEN_NO_DATA $
  ELSE BEGIN
    TMP_BAND  = CONVERT_INDEX_TO_WAVELENGTH(RES[0],TEMP_SENSOR1)
    PRD_STR   = STRING(RC_FOLDER +'SSEN_'      +RC_REGION+'_REF_'+REF_SENSOR+'_'+REF_PROC_VER+'_'+TMP_BAND+'.DAT')
 
    IF FILE_TEST(PRD_STR) EQ 0 THEN GOTO, SSEN_NO_DATA
    RAISE_NO_SDATA = 0
    RESTORE,PRD_STR
   
    SSEN_DATA = SS_DATA
    N = N_ELEMENTS(SSEN_DATA[0,*])
  
    SS_DATA = MAKE_ARRAY(N,2,/FLOAT)
    SS_DATA[*,0] = SSEN_DATA[0,*]
    SS_DATA[*,1] = SSEN_DATA[NUM_NON_REF,*]  
  ENDELSE
 
  SSEN_NO_DATA:
  IF RAISE_NO_SDATA THEN BEGIN
    PRINT, 'DIMITRI_VISU_SUPER: NO DATA FOUND, RETURNING'
    RETURN,{ERROR:1,SS_DATA:MAKE_ARRAY(5,2,/FLOAT)}
  ENDIF 

;-------------------------------- 
; RETURN THE SUPERSENSOR RHO ARRAY

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DIMITRI_VISU_SUPER: RETURNING DATA STRUCTURE' 
  VISU_SSEN = {                                             $
              ERROR:0                                      ,$
              SS_DATA:SS_DATA                               $
              }

  RETURN,VISU_SSEN

END
