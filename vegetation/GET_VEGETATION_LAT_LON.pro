;;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      GET_VEGETATION_LAT_LON      
;* 
;* PURPOSE:
;*      RETIREVES THE L1B LAT LON FROM A VEGETATION LOG FILE
;* 
;* CALLING SEQUENCE:
;*      RES = GET_VEGETATION_LAT_LON(LOG_FILE)      
;* 
;* INPUTS:
;*      LOG_FILE   -  THE FULL PATH OF THE PRODUCTS LOG FILE     
;*
;* KEYWORDS:
;*      VERBOSE    - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      STRUCT.LAT  - DERIVED PRODUCT LATITUDE
;*      STRUCT.LON  - DERIVED PRODUCT LONGITUDE
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*        17 DEC 2010 - C KENT    - DIMITRI-2 V1.0
;*
;* VALIDATION HISTORY:
;*        02 DEC 2010 - C KENT    - WINDOWS 32BIT MACHINE IDL 7.1: COMPILATION AND EXECUTION 
;*                                  SUCCESSFUL. TESTED MULTIPLE OPTIONS ON MULTIPLE 
;*                                  PRODUCTS
;*        06 JAN 2011 - C KENT    - LINUX 64-BIT MACHINE IDL 8.0: COMPILATION SUCCESSFUL, 
;*                                  NO APPARENT DIFFERENCES WHEN COMPARED TO WINDOWS MACHINE
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION GET_VEGETATION_LAT_LON,LOG_FILE,VERBOSE=VERBOSE

;-------------------------------------------
; CHECK FILE EXISTS

  IF STRCMP(STRING(LOG_FILE),'') THEN BEGIN
    PRINT, 'VEGETATION LAT LON: ERROR, NO INPUT FILES PROVIDED, RETURNING...'
    RETURN,-1
  ENDIF  

;-------------------------------------------
; CHECK FILES EXIST

  TEMP = FILE_INFO(LOG_FILE)
  IF TEMP.EXISTS EQ 0 THEN BEGIN
    PRINT, 'VEGETATION LAT LON: ERROR, LAT/LON FILE DOES NOT EXIST'
    RETURN,{ERROR:-1}
  ENDIF  

;-------------------------------------------
; READ LOG FILE IN AS A BINARY STRING

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'VEGETATION LAT LON: READING LOG FILE'
  TEMP_LOG = READ_BINARY(LOG_FILE)
  TEMP_LOG = STRING(TEMP_LOG)

;-------------------------------------------  
; GET MAX AND MIN LAT AND LON VALUES

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'VEGETATION LAT LON: RETRIEVING MAX AND MIN LAT/LON'
  POS = STRPOS(TEMP_LOG,'GEO_UPPER_LEFT_LAT')
    NORTH_LAT = STRMID(TEMP_LOG,POS+26,11)+0.0
  POS = STRPOS(TEMP_LOG,'GEO_LOWER_RIGHT_LAT')
    SOUTH_LAT = STRMID(TEMP_LOG,POS+26,11)+0.0
  POS = STRPOS(TEMP_LOG,'GEO_UPPER_LEFT_LONG')
    WEST_LON = STRMID(TEMP_LOG,POS+26,11)+0.0
  POS = STRPOS(TEMP_LOG,'GEO_LOWER_RIGHT_LONG')
    EAST_LON = STRMID(TEMP_LOG,POS+26,11)+0.0   

;-------------------------------------------
; GET IMAGE SIZE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'VEGETATION LAT LON: RETRIEVING PIXEL IMAGE SIZE'
  POS = STRPOS(TEMP_LOG,'IMAGE_LOWER_RIGHT_ROW')
  POS2 = STRPOS(TEMP_LOG,'IMAGE_LOWER_RIGHT_COL')
  POS3 = STRPOS(TEMP_LOG,'IMAGE_LOWER_LEFT_ROW')
  NUM_PIX_Y = STRMID(TEMP_LOG,POS+26,POS2-POS-26)+0.0   
  NUM_PIX_X = STRMID(TEMP_LOG,POS2+26,POS3-POS2-26)+0.0   

;-------------------------------------------
; CALCULATE LAT GRADIENT OVER COLUMN 0

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'VEGETATION LAT LON: DEFINE LAT AND LON GRIDS'
  NEW_GRID_LAT = MAKE_ARRAY(NUM_PIX_X,NUM_PIX_Y,/FLOAT)
  NEW_GRID_LON = MAKE_ARRAY(NUM_PIX_X,NUM_PIX_Y,/FLOAT)

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'VEGETATION LAT LON: INTERPOLATE BETWEEN MAX AND MIN LATITUDES'
  GRAD = (SOUTH_LAT - NORTH_LAT)/NUM_PIX_Y
  FOR I=0l,NUM_PIX_Y-1 DO BEGIN
    NEW_GRID_LAT[*,I] = NORTH_LAT+GRAD*I
  ENDFOR

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'VEGETATION LAT LON: INTERPOLATE BETWEEN MAX AND MIN LONGITUDES'
  GRAD = (EAST_LON - WEST_LON)/NUM_PIX_X
  FOR I=0l,NUM_PIX_X-1 DO BEGIN
    NEW_GRID_LON[I,*] = WEST_LON+GRAD*I
  ENDFOR

;-------------------------------------------
; RETURN GEOLOCAITON INFORMATION

  RETURN,{LAT:NEW_GRID_LAT,LON:NEW_GRID_LON}

END