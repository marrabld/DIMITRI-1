;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      READ_DIMITRI_EXTRACT_TOA_NCDF   
;* 
;* PURPOSE:
;*      THIS FUNCTION READS THE DIMITRI EXTRACTED TOA SENSOR NETCDF FILES AND RETURNS 
;*      THE INFORMATION AS A STRUCTURE
;*
;* CALLING SEQUENCE:
;*      RES = READ_DIMITRI_EXTRACT_TOA_NCDF(NCDF_FILE)
;* 
;* INPUTS:
;*      NCDF_FILE - THE FULLY QUALIFIED PATH OF THE NETCDF FILE FOR READING
;*
;* KEYWORDS:
;*      VERBOSE   - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      NCDF_DATA - A STRUCTURE CONTAINING THE NETCDF INFORMATION
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*      23 AUG 2011 - C KENT   - DIMITRI-2 V1.0
;*      30 AUG 2011 - C KENT   - ADDED MANUAL CLOUD SCREENING OUTPUT TO NETCDF
;*
;* VALIDATION HISTORY:
;*      
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION READ_DIMITRI_EXTRACT_TOA_NCDF,NCDF_FILE,VERBOSE=VERBOSE

;************************************
; GET THE HARDCODED NETCDF INFORMATION

  DIM_NCDF = GET_DIMITRI_EXTRACT_TOA_NCDF_NAMES(VERBOSE=VERBOSE)
  ERROR_GOOD = 0
  ERROR_BAD  = 1

;************************************  
; CHECK IF NCDF DATA FILE IS PRESENT
 
  IF NOT FILE_TEST(NCDF_FILE) THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'READ_DIMITRI_EXTRACT_TOA_NCDF: NCDF FILE DOES NOT EXIST'
    NCDF_DATA = CREATE_STRUCT(DIM_NCDF,'ERROR',ERROR_BAD)
    RETURN,NCDF_DATA  
  ENDIF

;************************************   
; OPEN THE FILE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'READ_DIMITRI_EXTRACT_TOA_NCDF: OPENING NETCDF FILE'   
  NCID = NCDF_OPEN( NCDF_FILE,/NOWRITE) 

;************************************
; READ EACH OF THE GLOBAL ATTRIBUTES 

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'READ_DIMITRI_EXTRACT_TOA_NCDF: READING NETCDF ATTRIBUTES'   
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_FNAME_TITLE,ATT_FNAME,/GLOBAL 
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_TOOL_TITLE,ATT_TOOL,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_CTIME_TITLE,ATT_CTIME,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_MTIME_TITLE,ATT_MTIME,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_SENSOR_TITLE,ATT_SENSOR,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_PROCV_TITLE,ATT_PROCV,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_PRES_TITLE,ATT_PRES,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_NBANDS_TITLE,ATT_NBANDS,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_NDIRS_TITLE,ATT_NDIRS,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_SITEN_TITLE,ATT_SITEN,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_SITEC_TITLE,ATT_SITEC,/GLOBAL
  NCDF_ATTGET,NCID,DIM_NCDF.ATT_SITET_TITLE,ATT_SITET,/GLOBAL

;************************************
; READ EACH OF THE VARIABLES

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'READ_DIMITRI_EXTRACT_TOA_NCDF: READING NETCDF VARIABLES'   
  NCDF_VARGET, NCID,DIM_NCDF.VAR_PNAME_TITLE,VAR_PNAME  
  NCDF_VARGET, NCID,DIM_NCDF.VAR_PTIME_TITLE,VAR_PTIME
  NCDF_VARGET, NCID,DIM_NCDF.VAR_DTIME_TITLE,VAR_DTIME
  NCDF_VARGET, NCID,DIM_NCDF.VAR_PIX_TITLE,VAR_PIX
  NCDF_VARGET, NCID,DIM_NCDF.VAR_RHOMU_TITLE,VAR_RHOMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_RHOSD_TITLE,VAR_RHOSD
  NCDF_VARGET, NCID,DIM_NCDF.VAR_CLOUD_TITLE_AUT,VAR_CLOUD_AUT
  NCDF_VARGET, NCID,DIM_NCDF.VAR_CLOUD_TITLE_MAN,VAR_CLOUD_MAN
  NCDF_VARGET, NCID,DIM_NCDF.VAR_VZA_TITLE,VAR_VZA
  NCDF_VARGET, NCID,DIM_NCDF.VAR_VAA_TITLE,VAR_VAA
  NCDF_VARGET, NCID,DIM_NCDF.VAR_SZA_TITLE,VAR_SZA
  NCDF_VARGET, NCID,DIM_NCDF.VAR_SAA_TITLE,VAR_SAA
  NCDF_VARGET, NCID,DIM_NCDF.VAR_OZONEMU_TITLE,VAR_OZONEMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_OZONESD_TITLE,VAR_OZONESD
  NCDF_VARGET, NCID,DIM_NCDF.VAR_WVAPMU_TITLE,VAR_WVAPMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_WVAPSD_TITLE,VAR_WVAPSD
  NCDF_VARGET, NCID,DIM_NCDF.VAR_PRESSMU_TITLE,VAR_PRESSMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_PRESSSD_TITLE,VAR_PRESSSD
  NCDF_VARGET, NCID,DIM_NCDF.VAR_RHUMMU_TITLE,VAR_RHUMMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_RHUMSD_TITLE,VAR_RHUMSD
  NCDF_VARGET, NCID,DIM_NCDF.VAR_ZONALMU_TITLE,VAR_ZONALMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_ZONALSD_TITLE,VAR_ZONALSD
  NCDF_VARGET, NCID,DIM_NCDF.VAR_MERIDMU_TITLE,VAR_MERIDMU
  NCDF_VARGET, NCID,DIM_NCDF.VAR_MERIDSD_TITLE,VAR_MERIDSD

;************************************  
; CLOSE THE FILE

  NCDF_CLOSE, NCID

;************************************
; STORE THE DATA IN A STRUCTURE

  TEMP = {ERROR       : ERROR_GOOD      ,$
          ATT_FNAME   : ATT_FNAME       ,$
          ATT_TOOL    : ATT_TOOL        ,$
          ATT_CTIME   : ATT_CTIME       ,$
          ATT_MTIME   : ATT_MTIME       ,$
          ATT_SENSOR  : ATT_SENSOR      ,$
          ATT_PROCV   : ATT_PROCV       ,$
          ATT_PRES    : ATT_PRES        ,$
          ATT_NBANDS  : ATT_NBANDS      ,$
          ATT_NDIRS   : ATT_NDIRS       ,$
          ATT_SITEN   : ATT_SITEN       ,$
          ATT_SITEC   : ATT_SITEC       ,$
          ATT_SITET   : ATT_SITET       ,$
          VAR_PNAME   : VAR_PNAME       ,$
          VAR_PTIME   : VAR_PTIME       ,$
          VAR_DTIME   : VAR_DTIME       ,$
          VAR_PIX     : VAR_PIX         ,$
          VAR_RHOMU   : VAR_RHOMU       ,$
          VAR_RHOSD   : VAR_RHOSD       ,$
          VAR_CLOUD_AUT   : VAR_CLOUD_AUT       ,$
          VAR_CLOUD_MAN   : VAR_CLOUD_MAN       ,$
          VAR_VZA     : VAR_VZA         ,$
          VAR_VAA     : VAR_VAA         ,$
          VAR_SZA     : VAR_SZA         ,$
          VAR_SAA     : VAR_SAA         ,$
          VAR_OZONEMU : VAR_OZONEMU     ,$
          VAR_OZONESD : VAR_OZONESD     ,$
          VAR_WVAPMU  : VAR_WVAPMU      ,$
          VAR_WVAPSD  : VAR_WVAPSD      ,$
          VAR_PRESSMU : VAR_PRESSMU     ,$
          VAR_PRESSSD : VAR_PRESSSD     ,$
          VAR_RHUMMU  : VAR_RHUMMU      ,$
          VAR_RHUMSD  : VAR_RHUMSD      ,$
          VAR_ZONALMU : VAR_ZONALMU     ,$
          VAR_ZONALSD : VAR_ZONALSD     ,$
          VAR_MERIDMU : VAR_MERIDMU     ,$
          VAR_MERIDSD : VAR_MERIDSD     }

  NCDF_DATA = CREATE_STRUCT(DIM_NCDF,TEMP)

;************************************
; RETURN THE STURCTURE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'READ_DIMITRI_EXTRACT_TOA_NCDF: RETURNING DATA STRUCTURE' 
  RETURN,NCDF_DATA

END