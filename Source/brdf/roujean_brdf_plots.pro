;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      ROUJEAN_BRDF_PLOTS       
;* 
;* PURPOSE:
;*      GENERATES 3D BRDF PLOTS FOR A GIVEN SENSOR,ROUJEAN COEFICIENTS AND BIN DATE
;* 
;* CALLING SEQUENCE:
;*      RES = ROUJEAN_BRDF_PLOTS(JPEG_NAME_BASE,BD_REGION,K1_ROUJEAN,K2_ROUJEAN,K3_ROUJEAN,ERR_ROUJEAN)      
;* 
;* INPUTS:
;*      JPEG_NAME_BASE  - A STRING OF THE BASE FILENAME OUTPUT (FULL PATH) E.G. 'Z:\DIMITRI_CODE\DIMITRI_2.0\OUTPUT\DOUBLET_EXTRACTION_TEST\ROUJEAN_BRDF\' 
;*      BD_REGION       - THE VALIDATION SITE NAME E.G. 'UYUNI'
;*      BD_SENSOR       - THE REFERENCE SENSOR NAME      
;*      K1_ROUJEAN      - THE ARRAY OF ROUJEAN K1 COEFICIENTS FOR EACH BAND AS COMPUTED IN ROUJEAN_BRDF
;*      K2_ROUJEAN      - THE ARRAY OF ROUJEAN K2 COEFICIENTS FOR EACH BAND AS COMPUTED IN ROUJEAN_BRDF
;*      K3_ROUJEAN      - THE ARRAY OF ROUJEAN K3 COEFICIENTS FOR EACH BAND AS COMPUTED IN ROUJEAN_BRDF
;*      ERR_ROUJEAN     - THE ARRAY OF ROUJEAN ERROR COEFICIENTS FOR EACH BAND AS COMPUTED IN ROUJEAN_BRDF
;*
;* KEYWORDS:
;*      BRDF_SZA        - THE REQUESTED SZA VALUE (DEFAULT IS 45.0)
;*      N_POINTS        - THE NUMBER OF POINTS TO COMPUTE THE BRDF RHO FOR (DEFUALT IS 800 = 800X800)
;*      NO_ZBUFF        - SET THIS TO GENERATE PLOT WINDOWS AND NOT JUST IN THE Z_BUFFER
;*      VERBOSE         - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      STATUS            - 1: NO ERRORS REPORTED, (-1) OR 0: ERRORS DURING INGESTION 
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*        25 JAN 2011 - C KENT    - DIMITRI-2 V1.0
;*
;* VALIDATION HISTORY:
;*        15 APR 2011 - C KENT   - WINDOWS 32-BIT IDL 7.1 AND LINUX 64-BIT IDL 8.0 NOMINAL
;*                                 COMPILATION AND OPERATION. TESTED ON MERIS 2ND REPROCESSING 
;*                                 WITH MERIS 3RD REPROCESSING AND MODISA COLLECTION 5
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION ROUJEAN_BRDF_PLOTS,JPEG_NAME_BASE,BD_REGION,BD_SENSOR,K1_ROUJEAN,K2_ROUJEAN,K3_ROUJEAN,ERR_ROUJEAN,$
                            BRDF_SZA=BRDF_SZA,N_POINTS=N_POINTS,NO_ZBUFF=NO_ZBUFF,VERBOSE=VERBOSE

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: STARTING ROUJEAN RHO PLOTS'

;----------------------------------------
; CHECK KEYWORD STATUS

  IF N_ELEMENTS(BRDF_SZA) EQ 0 THEN BEGIN
    PRINT, 'ROUJEAN_BRDF_PLOTS: NO SZA PROVIDE USING DEFAULT OF 45.0'
    BRDF_SZA = 45.0
  ENDIF
  IF N_ELEMENTS(N_POINTS) EQ 0 THEN BEGIN
    PRINT, 'ROUJEAN_BRDF_PLOTS: NO N_POINTS PROVIDE USING DEFAULT OF 800 IN EACH DIRECTION'
    N_POINTS = 800.0
  ENDIF

;----------------------------------------
; CHECK VZA IS WITHIN VALID RANGE

  IF BRDF_SZA GT 90.0 OR BRDF_SZA LT 0.0 THEN BEGIN
    PRINT, 'ROUJEAN_BRDF_PLOTS: SZA ANGLE OUT OF RANGE'
    RETURN,-1
  ENDIF
  IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: SZA ANGLE VALID'
;----------------------------------------
; SET WINDOW PROPERTIES

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: SETTING DISPLAY PROPERTIES'
  XSIZE = 800 
  YSIZE = 800  
  MACHINE_WINDOW = !D.NAME
  IF NOT KEYWORD_SET(NO_ZBUFF) THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'ROUJEAN_BRDF_PLOTS: GENERATING PLOTS WITHIN Z-BUFFER'
    SET_PLOT, 'Z'
    DEVICE, SET_RESOLUTION=[XSIZE,YSIZE],set_pixel_depth=24
    ERASE  
  ENDIF ELSE BEGIN
    SET_PLOT,'WIN'
    WINDOW,XSIZE=XSIZE,YSIZE=YSIZE
  ENDELSE
  
  DEVICE, DECOMPOSED = 0
  LOADCT, 1
  SET_SHADING, LIGHT=[1,0, 1]

;----------------------------------------  
; SET LOOP VARIABLES 
 
  NON_BRDF =2
  TEMP_SIZE  = SIZE(K1_ROUJEAN)
  NBANDS    = TEMP_SIZE[1]-NON_BRDF
  CPT_IMAGES = 0

;----------------------------------------
; START LOOP OVER EACH BAND   

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: STARTING LOOP OVER EACH BAND'
  FOR IBAND=0,NBANDS-1 DO BEGIN

;----------------------------------------
; START LOOP OVER EACH BIN 
 
    IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: STARTING LOOP OVER EACH BIN'
    FOR I_BIN=0, N_ELEMENTS(K1_ROUJEAN(0,*))-1 DO BEGIN

;----------------------------------------      
; ONLY PERFORM BRDF COMPUTAITON IF NOMINAL 
; DATA AVAILABLE

      IF K1_ROUJEAN(non_brdf+IBAND,I_BIN) NE -999. THEN BEGIN
        
        TEMP    = FINDGEN(N_POINTS)/(N_POINTS/2.0)-1.00001
        X_ARR   = FLTARR(N_ELEMENTS(TEMP),N_ELEMENTS(TEMP))
        Y_ARR   = FLTARR(N_ELEMENTS(TEMP),N_ELEMENTS(TEMP))

;----------------------------------------
; FILL THE X AND Y ARRAYS      
 
        FOR I=0L,N_POINTS-1 DO BEGIN
          X_ARR[I,*] = TEMP[I]
          Y_ARR[*,I] = TEMP[I]
        ENDFOR
;----------------------------------------
; SET BRDF, VZA AND DPHI VARIABLES 
  
        BRDF_VAL    = X_ARR
        BRDF_VAL[*] = -1.0
        VZA         = ABS(180./!DPI*ASIN(X_ARR/COS(ATAN(Y_ARR/X_ARR))))
        DPHI        = 180./!DPI*ATAN(Y_ARR/X_ARR)

;----------------------------------------
; FIND CONTOUR LINES

        RES = WHERE(X_ARR LT 0. AND Y_ARR LT 0.)
          IF RES[0] GT -1 THEN DPHI[RES] = 180.+DPHI[RES]
        RES = WHERE(X_ARR LT 0. AND Y_ARR GT 0.)
          IF RES[0] GT -1 THEN DPHI[RES] = 180.-DPHI[RES]
        RES = WHERE(ABS(Y_ARR) LT 0.001)
          IF RES[0] GT -1 THEN BRDF_VAL[RES] = 0.0
        RES = WHERE(ABS(VZA) GT 59.9 AND ABS(VZA) LT 60.1 AND BRDF_VAL LT 0.0) 
          IF RES[0] GT -1 THEN BRDF_VAL[RES] = 0.0   
        RES = WHERE(ABS(VZA) GT 29.9 AND ABS(VZA) LT 30.1 AND BRDF_VAL LT 0.0) 
          IF RES[0] GT -1 THEN BRDF_VAL[RES] = 0.0   

;----------------------------------------
; FIND THE LOCATION SO THE NON-SET BRDF 
; VALUES AND COMPUTE THE BRDF RHO

        RES = WHERE(BRDF_VAL LT 0.0)
        IF RES[0] GT -1 THEN BEGIN
         IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: COMPUTING ROUJEAN RHO OVER GRID'
         BRDF_VAL[RES]=ROUJEAN_BRDF_COMPUTE_RHO(BRDF_SZA,VZA[RES],DPHI[RES],[K1_ROUJEAN(non_brdf+IBAND,I_BIN),K2_ROUJEAN(non_brdf+IBAND,I_BIN),K3_ROUJEAN(non_brdf+IBAND,I_BIN)],/DEGREES)
        ENDIF

;----------------------------------------    
; CHANGE ALL NEGATIVES TO NANS
        
        RES = WHERE(BRDF_VAL LT 0.0 or BRDF_VAL GT 1.0)
        IF RES[0] GT -1 THEN BRDF_VAL[RES] = !VALUES.F_NAN

;----------------------------------------    
; COMPUTE THE DATE
      
        DEC_DATE = K1_ROUJEAN(0,I_BIN)
        YEAR = FLOOR(DEC_DATE)
        DOY = (DEC_DATE-FLOAT(YEAR))*365.0
        JDAY = JULDAY(1,1,YEAR)
        JDAY = JDAY+DOY
        CALDAT,JDAY,TMONTH,TDAY,TYEAR
        IF TDAY LT 10 THEN   TDAY    = '0'+STRTRIM(STRING(TDAY),2)   ELSE TDAY   = STRTRIM(STRING(TDAY),2) 
        IF TMONTH LT 10 THEN TMONTH  = '0'+STRTRIM(STRING(TMONTH),2) ELSE TMONTH = STRTRIM(STRING(TMONTH),2)
        TYEAR = STRTRIM(STRING(TYEAR),2)
        DATE = STRING(TYEAR+TMONTH+TDAY)       

        IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: GENERATING PLOT'
        
        SHADE_SURF,  BRDF_VAL, X_ARR, Y_ARR,$ 
        AZ=40, AX=30, MIN_VALUE=0.01, $
        BACKGROUND=0, COLOR=255, $
        ZRANGE=[0.0,1.0], CHARSIZE=2, XRANGE=[-1,1], YRANGE=[-1,1], $
        ZTITLE='TOA RHO', XTITLE=' ',ytitle='', $
        XGRIDSTYLE=3, YGRIDSTYLE=4
        
        XYOUTS,0.5,0.95,'ROUJEAN BRDF ON '+TDAY+'/'+TMONTH+'/'+TYEAR,CHARSIZE=2,COLOR=255,ALIGNMENT=0.5,/NORMAL
        XYOUTS,0.02,0.08,'SOLAR ZENITH ANGLE : '+ STRTRIM(STRING(BRDF_SZA),2),CHARSIZE=1,COLOR=255,/NORMAL
        XYOUTS,0.02,0.06,'NUM. SENSOR OBS.   : '+ STRTRIM(STRING(K1_ROUJEAN(1,I_BIN)),2),CHARSIZE=1,COLOR=255,/NORMAL
        XYOUTS,0.02,0.02,'RETRIEVAL RMSE FIT : '+ STRTRIM(STRING(ERR_ROUJEAN[NON_BRDF+IBAND,I_BIN]),2)+'%',CHARSIZE=1,COLOR=255,/NORMAL

;----------------------------------------    
; SAVE THE PLOT
  
        TEMP = STRTRIM(STRING(CPT_IMAGES))
        IF CPT_IMAGES LT 10 THEN TEMP = STRING('000'+STRTRIM(STRING(CPT_IMAGES)))
        IF CPT_IMAGES LT 100 THEN TEMP = STRING('00'+STRTRIM(STRING(CPT_IMAGES)))
        IF CPT_IMAGES LT 1000 THEN TEMP = STRING('0'+STRTRIM(STRING(CPT_IMAGES)))
        
        IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: SAVING PLOT'
        TBAND = CONVERT_INDEX_TO_WAVELENGTH(IBAND,BD_SENSOR)
        WRITE_JPEG, STRING(JPEG_NAME_BASE+'BRDF_'+BD_REGION+'_BAND_'+TBAND+'_'+DATE+'.JPG'), $
        REVERSE(TVRD(TRUE=3),2), TRUE=3, /ORDER, QUALITY=100
        CPT_IMAGES++
      ENDIF
    ENDFOR
  ENDFOR 
  
;----------------------------------------   
; RETURN DISPLAY TO PREVIOUS SETTINGS
  
  IF KEYWORD_SET(NO_ZBUFF) THEN WDELETE
  SET_PLOT, MACHINE_WINDOW
  IF KEYWORD_SET(VERBOSE) THEN PRINT,'ROUJEAN_BRDF_PLOTS: RETURNING NOMINAL STATUS'
  RETURN,1

END