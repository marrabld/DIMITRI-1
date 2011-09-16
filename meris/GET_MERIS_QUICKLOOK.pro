;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      GET_MERIS_QUICKLOOK       
;* 
;* PURPOSE:
;*      OUTPUTS A RGB MERIS QUICKLOOK WITH ROI OVERLAY IF REQUESTED
;* 
;* CALLING SEQUENCE:
;*      RES = GET_MERIS_QUICKLOOK(FILENAME)      
;* 
;* INPUTS:
;*      FILENAME - A SCALAR CONTAINING THE FILENAME OF THE PRODUCT FOR QUICKLOOK GENERATION 
;*
;* KEYWORDS:
;*     RGB          -  PROGRAM GENERATES AN RGB COLOUR QUICKLOOK (DEFAULT IS GRAYSCALE)
;*     ROI          -  OVERLAY COORDINATES OF AN ROI IN RED (REQUIRES ICOORDS)
;*     ICOORDS      -  A 4-ELEMENT ARRAY OF ROI GEOLOCATION (N,S,E,W) 
;*     QL_QUALITY   -  QUALITY OF JPEG GENERATED (100 = MAX, 0 = LOWEST)
;*     ENDIAN_SIZE  - MACHINE ENDIAN SIZE (0: LITTLE, 1: BIG)
;*     VERBOSE      - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*     STATUS       - 1: NOMINAL, (-1) OR 0: ERROR
;*     JPESG ARE AUTOMATICALLY SAVED IN FILENAME FOLDER    
;*
;* COMMON BLOCKS:
;*     NONE 
;*
;* MODIFICATION HISTORY:
;*     13 FEB 2002 - M BOUVET - PROTOTYPE DIMITRI VERSION
;*     17 NOV 2010 - C KENT   - DIMITRI-2 V1.0
;*     17 NOV 2010 - C KENT   - NEW KEYWORDS AND OUTPUTS, NEW LAYOUT TO ALLOW RGB AND GRAYCOLOUR PROCESSING
;*     22 NOV 2010 - C KENT   - ADDED VERBOSE KEYWORD OPTION
;*     01 DEC 2010 - C KENT   - ADDED FILENAME ERROR HANDLING
;*     02 DEC 2010 - C KENT   - UPDATED HEADER INFORMATION
;*     12 SEP 2011 - C KENT   - ADDED MERIS LON_CORR FIX
;*
;* VALIDATION HISTORY:
;*     01 DEC 2010 - C KENT   - WINDOWS 32-BIT MACHINE IDL 7.1: COMPILATION SUCCESSFUL,
;*                              RGB,ROI,ICOORDS AND QL_QUALITY KEYWORDS TESTED 
;*                              SUCCESSFULLY USING UYUNI COORDINATES
;*     05 JAN 2011 - C KENT   - LINUX 64-BIT MACHINE IDL 8.0: COMPILATION SUCCESSFUL,
;*                              RGB,ROI,ICOORDS AND QL_QUALITY KEYWORDS TESTED 
;*                              SUCCESSFULLY USING UYUNI COORDINATES
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION GET_MERIS_QUICKLOOK,FILENAME,RGB=RGB,ROI=ROI,ICOORDS=ICOORDS,QL_QUALITY=QL_QUALITY,ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE

;------------------------------------------------
; CHECK FILENAME AND IN_BAND ARE NOMINAL

  IF FILENAME EQ '' THEN BEGIN
    PRINT, 'MERIS L1B QUICKLOOK: ERROR, INPUT FILENAME INCORRECT'
    RETURN,-1
  ENDIF

;------------------------------------------------
; IF ENDIAN SIZE NOT PROVIDED THEN GET VALUE

  IF N_ELEMENTS(ENDIAN_SIZE) EQ 0 THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN BEGIN
      PRINT, 'MERIS L1B QUICKLOOK: NO ENDIAN SIZE PROVIDED, RETRIEVING...'
      ENDIAN_SIZE = GET_ENDIAN_SIZE(/VERBOSE)
    ENDIF ELSE ENDIAN_SIZE = GET_ENDIAN_SIZE()
  ENDIF
  
;------------------------------------------------
; SET JPEG QUALITY IF NOT PROVIDED

  IF N_ELEMENTS(QL_QUALITY) EQ 0 THEN QL_QUALITY = 90
  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: JPEG QUALITY = ',QL_QUALITY
  
;------------------------------------------------
; CHECK KEYWORD COMBINATIONS

  IF KEYWORD_SET(ROI) AND N_ELEMENTS(ICOORDS) LT 4 THEN BEGIN
    PRINT,'ERROR: ROI KEYWORD IS SET BUT COORDINATES INCORRECT'
    PRINT,'RETURNING'
    RETURN,-1
  ENDIF

;------------------------------------------------
; DERIVE THE OUTPUT JPEG FILENAME

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: COMPUTING OUTPUT FILENAME'
  QL_POS = STRPOS(FILENAME,'.',/REVERSE_SEARCH)
  QL_MERIS_JPG = FILENAME
  STRPUT,QL_MERIS_JPG,'_',QL_POS
  QL_MERIS_JPG = STRING(QL_MERIS_JPG+'.jpg')

;------------------------------------------------
; GET MERIS L1B RADIANCE DATA AND DERIVEQUICKLOOK IMAGE

  IF KEYWORD_SET(RGB) THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: RGB JPEG SELECTED'
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: RETRIEVING RGB RADIANCE DATA'
    QL_DATAR = REVERSE(GET_MERIS_L1B_RADIANCE(FILENAME,6,ENDIAN_SIZE=ENDIAN_SIZE),1)
    QL_DATAG = REVERSE(GET_MERIS_L1B_RADIANCE(FILENAME,4,ENDIAN_SIZE=ENDIAN_SIZE),1)
    QL_DATAB = REVERSE(GET_MERIS_L1B_RADIANCE(FILENAME,0,ENDIAN_SIZE=ENDIAN_SIZE),1)
  ENDIF ELSE BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: RETRIEVING RADIANCE 13 DATA'
    QL_DATAR  = REVERSE(GET_MERIS_L1B_RADIANCE(FILENAME,12,ENDIAN_SIZE=ENDIAN_SIZE),1)
  ENDELSE
  
  IF QL_DATAr[0] EQ -1 THEN BEGIN
    PRINT,'MERIS L1B QUICKLOOK: ERROR, PROBLEM ENCOUNTERED DURING L1B RADIANCE RETRIEVAL, CHECK PRODUCTS IS A MERIS L1B PRODUCT'
    PRINT,'RETURNING'
    RETURN,-1
  ENDIF

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: GET PRODUCT DIMENSIONS AND DEFINE IMAGE ARRAY'
  QL_DIMS  = SIZE(QL_DATAR)
  QL_IMAGE = BYTARR(3,QL_DIMS[1],QL_DIMS[2])
  
;-----------------------------------------------
; POPULATE THE QUICKLOOK IMAGE ARRAY  

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: ADD RADIANCE DATA TO IMAGE ARRAY CHANNELS'
  IF KEYWORD_SET(RGB) THEN BEGIN 
   
    QL_IMAGE[0,*,*]=BYTSCL(QL_DATAR)
    QL_IMAGE[1,*,*]=BYTSCL(QL_DATAG)
    QL_IMAGE[2,*,*]=BYTSCL(QL_DATAB)

;----------------------------------------------
; RELEASE MEMORY FOR GREEN AND BLUE CHANNELS
    
    QL_DATAG = 0
    QL_DATAB = 0
    
  ENDIF ELSE BEGIN
    QL_IMAGE[0,*,*]=BYTE(QL_DATAR)
    QL_IMAGE[1,*,*]=BYTE(QL_DATAR)
    QL_IMAGE[2,*,*]=BYTE(QL_DATAR)
  ENDELSE

;---------------------------------------------------
; GET LAT/LON DATA FOR ROI PIXEL INDEX IF REQUESTED

  IF KEYWORD_SET(ROI) THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: OVERLAY OF ROI SELECTED'
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: RETRIEVING PRODUCT GEOLOCATION'
    QL_GEO = GET_MERIS_LAT_LON(FILENAME,ENDIAN_SIZE=ENDIAN_SIZE)
    TEMP = GET_MERIS_VIEWING_GEOMETRIES(FILENAME,ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
    TEMP_ANGLES = DIMITRI_ANGLE_CORRECTOR(TEMP.VZA,TEMP.VAA,TEMP.SZA,TEMP.SAA)
 
 ;----------------------------------
; CORRECT LON AND LAT ALTITUDE

    RES = WHERE(TEMP_ANGLES.VAA GE 0. AND TEMP_ANGLES.VAA LT 180.,COUNT,COMPLEMENT=RSIGN,NCOMPLEMENT=RCOUNT)
    IF COUNT  GT 0 THEN QL_GEO.LON_CORR[RES]     =  1*ABS(QL_GEO.LON_CORR[RES])
    IF RCOUNT GT 0 THEN QL_GEO.LON_CORR[RSIGN]   = -1*ABS(QL_GEO.LON_CORR[RSIGN])
    LAT = QL_GEO.LAT+QL_GEO.LAT_CORR
    LON = QL_GEO.LON+QL_GEO.LON_CORR
    QL_GEO = 0
    
;---------------------------------------------------
; REVERSE GEOLOCATION ARRAYS INTO SAME ORIENTAITON AS RADIANCE

    LAT = REVERSE(LAT)
    LON = REVERSE(LON)
           
    QL_ROI_IDX = WHERE($
          LAT LT ICOORDS[0] AND $
          LAT GT ICOORDS[1] AND $
          LON LT ICOORDS[2] AND $
          LON GT ICOORDS[3] )

;---------------------------------------------------
; CONVERT ROI PIXELS TO A LIGHT RED OVERLAY

    IF QL_ROI_IDX[0] GT -1 THEN BEGIN
          IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: MODIFYING RED CHANNEL FOR ROI OVERLAY'
          QL_IMAGE = BYTSCL(QL_IMAGE,TOP=255)
         
          QL_DATAR = QL_IMAGE[0,*,*]
          QL_DATAG = QL_IMAGE[1,*,*]
          QL_DATAB = QL_IMAGE[2,*,*]
        
          QL_DATAR[QL_ROI_IDX]=250
          QL_DATAG[QL_ROI_IDX]=bytscl(QL_DATAG[QL_ROI_IDX],top=80)
          QL_DATAB[QL_ROI_IDX]=bytscl(QL_DATAb[QL_ROI_IDX],top=80)
          QL_IMAGE[0,*,*] = QL_DATAR
          QL_IMAGE[1,*,*] = QL_DATAG
          QL_IMAGE[2,*,*] = QL_DATAB
          
    ENDIF
  ENDIF

;---------------------------------------------------
; OUTPUT QUICKLOOK AS JPEG

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MERIS L1B QUICKLOOK: WRITING IMAGE TO JPEG'
  WRITE_JPEG ,QL_MERIS_JPG,QL_IMAGE,TRUE=1,/ORDER
  
;---------------------------------------------------
; RETURN A POSITIVE VALUE INDICATING QL GENERATION OK

  RETURN, 1

END
