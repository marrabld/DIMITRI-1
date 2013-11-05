;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      INGEST_MERIS_PRODUCT       
;* 
;* PURPOSE:
;*      INGESTS MERIS L1B DATA INTO DIMITRI DATABASE. MULTIPLE PRODUCT 
;*	    EXTRACTION IS AVAILABLE BUT IT EXPECTS ALL FILES TO BE THE SAME REGION/PROCESSING. 
;*      OUTPUTS QUICKLOOK IMAGES, UPDATES DATABASE AND APPENDS DATA TO SAV FILE FOR 
;*      SPECIFIED REGION AND PROCESSING.
;* 
;* CALLING SEQUENCE:
;*      RES = INGEST_MERIS_PRODUCT(IFILES)      
;* 
;* INPUTS:
;*      IFILES -  A STRING OR STRING ARRAY OF THE FULL PATH FILENAMES OF PRODUCTS 
;*                FOR INGESTION.      
;*
;* KEYWORDS:
;*      INPUT_FOLDER      - A STRING CONTAINING THE FULL PATH OF THE 'INPUT' FOLDER, IF 
;*                          NOT PROVIDED THEN IT IS DERIVED FROM THE FILENAME
;*      ICOORDS           - A FOUR ELEMENT FLOATING-POINT ARRAY CONTAINING THE NORTH, SOUTH, 
;*                          EAST AND WEST COORDINATES OF THE ROI, E.G [50.,45.,10.,0.]
;*      ENDIAN_SZE        - MACHINE ENDIAN SIZE (0: LITTLE, 1: BIG), IF NOT PROVIDED 
;*                          THEN COMPUTED.
;*      COLOUR_TABLE      - USER DEFINED IDL COLOUR TABLE INDEX (DEFAULT IS 39)
;*      PLOT_XSIZE        - WIDTH OF GENERATED PLOTS (DEFAULT IS 700PX)
;*      PLOT_YSIZE        - HEIGHT OF GENERATED PLOTS (DEFAULT IS 400PX)
;*      NO_ZBUFF          - IF SET THEN PLOTS ARE GENERATED IN WINDOWS AND NOT 
;*                          WIHTIN THE Z-BUFFER.
;*      NO_QUICKLOOK      - IF SET THEN QUICKLOOKS ARE NOT GENERATED FOR IFILES.
;*      VERBOSE           - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      STATUS  - 1: NO ERRORS REPORTED, (-1) OR 0: ERRORS DURING INGESTION	
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*        04 JUL 2005 - M BOUVET  - PROTOTYPE DIMITRI VERSION
;*        09 NOV 2010 - C KENT    - DIMITRI-2 V1.0
;*        20 NOV 2010 - C KENT    - UPDATED TO ALLOW SINGULAR USAGE (REMOVED COMMON BLOCKS)
;*        22 NOV 2010 - C KENT    - ADDED VERBOSE KEYWORD OPTION
;*        02 DEC 2010 - C KENT    - UPDATED PROGRAMMING AND SZA TO PIXEL DATA INSTEAD OF 
;*                                  AVERAGE WHEN COMPTING TOA REFLECTANCE. 
;*                                  HEADER ALSO UPDATED
;*        03 DEC 2010 - C KENT    - REMOVED NB_PIX THRESHOLD, ALL PRODUCT APPENDED TO DATABASE, 
;*                                  NO DATA FILES ARE SET TO -1
;*        20 DEC 2010 - C KENT    - UPDATED COMMENTS AND HEADER INFORMATION
;*        10 JAN 2011 - C KENT    - CHANGED SAVED OUTPUT VARIABLE TO SENSOR_L1B_REF
;*        12 JAN 2011 - C KENT    - OUTPUT RGB QUICKLOOKS AS DEFUALT, UPDATED OUTPUT DATA 
;*                                  WITH SAA AND VAA (REMOVED RAA) 
;*        21 MAR 2011 - C KENT    - MODIFIED FILE DEFINITION TO USE GET_DIMITRI_LOCATION
;*        22 MAR 2011 - C KENT    - ADDED CONFIGURAITON FILE DEPENDENCE
;*        01 JUL 2011 - C KENT    - ADDED ANGLE CORRECTOR
;*        04 JUL 2011 - C KENT    - UPDATED TO INCLUDE NEW AUXILARY INFORMATION, 
;*                                  AND CODE REVISION TO IMPROVE PERFORMANCE (SOLAR IRRADIANCE COMPUTATION)
;*        12 JUL 2011 - C KENT    - FIXED AUX INFO BUG
;*        14 JUL 2011 - C KENT    - UPDATED TIME EXTRACTION SECTION
;*        23 AUG 2011 - C KENT    - ADD NETCDF OUTPUT FUNCTIONALITY
;*        24 AUG 2011 - C KENT    - UPDATED NETCDF OUTPUT FUNCTIONALITY
;*        30 AUG 2011 - C KENT    - ADDED MANUAL CLOUD SCREENING OUTPUT TO NETCDF
;*        12 SEP 2011 - C KENT    - UPDATED NETCDF OUTPUT
;*        08 MAR 2012 - C KENT    - ADDED ROI COVERAGE
;*        01 NOV 2013 - C MAZERAN - CHANGED CODE STRUCTURE TO ADD PIXEL BY PIXEL EXTRACTION
;*
;* VALIDATION HISTORY:
;*        02 DEC 2010 - C KENT    - WINDOWS 32BIT MACHINE IDL 7.1: COMPILATION AND EXECUTION 
;*                                  SUCCESSFUL. TESTED MULTIPLE OPTIONS ON MULTIPLE 
;*                                  PRODUCTS
;*        12 APR 2011 - C KENT    - LINUX 64BIT MACHINE IDL 8.0: COMPILATION AND OPERATION SUCCESSFUL 
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION INGEST_MERIS_PRODUCT,IFILES,INPUT_FOLDER=INPUT_FOLDER,ICOORDS=ICOORDS,$
         ENDIAN_SZE=ENDIAN_SIZE,COLOUR_TABLE=COLOUR_TABLE,$
         PLOT_XSIZE=PLOT_XSIZE,PLOT_YSIZE=PLOT_YSIZE,NO_ZBUFF=NO_ZBUFF,NO_QUICKLOOK=NO_QUICKLOOK,$
         VERBOSE=VERBOSE

;------------------------
; DEFINE CURRENT FUNCTION NAME

  FCT_NAME = "INGEST_MERIS_PRODUCT"

;------------------------
; KEYWORD PARAMETER CHECK - NOTE, ASSUMES ALL PRODUCT ARE RELATED TO THE SAME REGION/PROCESSING

  IF STRCMP(STRING(IFILES[0]),'') THEN BEGIN
    PRINT, FCT_NAME+': ERROR, NO INPUT FILES PROVIDED, RETURNING...'
    RETURN,-1
  ENDIF  
  IF N_ELEMENTS(INPUT_FOLDER) EQ 0 THEN INPUT_FOLDER = GET_DIMITRI_LOCATION('INPUT')

  DELIM = GET_DIMITRI_LOCATION('DL')
  TEMP = STRSPLIT(IFILES[0],DELIM,/EXTRACT)
 
  TEMP_INF  = WHERE(STRCMP(TEMP,'Input') EQ 1)
  TEMP_INF  = TEMP_INF(N_ELEMENTS(TEMP_INF)-1)
  IREGION   = TEMP[TEMP_INF+1]
  IREGION   = STRMID(IREGION,5,STRLEN(IREGION)) 
  SENSOR    = TEMP[TEMP_INF+2]
  IPROC     = TEMP[TEMP_INF+3]
  IPROC     = STRMID(IPROC,5,STRLEN(IPROC)) 
  CFIG_DATA = GET_DIMITRI_CONFIGURATION()
  BADVAL    = -999.0
  MER_SITE_TYPE = GET_SITE_TYPE(IREGION,VERBOSE=VERBOSE)
  
  IF N_ELEMENTS(ICOORDS) EQ 0 THEN BEGIN
    PRINT, FCT_NAME+': NO ROI COORDINATES PROVIDED, USING DEFAULT OF [90.,-90,180.0,-180.0]'
    ICOORDS = [90.,-90.,180.0,-180.0]
  ENDIF
  IF N_ELEMENTS(COLOUR_TABLE) EQ 0 THEN BEGIN
    PRINT, FCT_NAME+': NO COLOR_TABLE SET, USING DEFAULT OF 39'
    COLOUR_TABLE = CFIG_DATA.(1)[2]
  ENDIF
  IF N_ELEMENTS(PLOT_XSIZE) EQ 0 THEN BEGIN
    PRINT, FCT_NAME+': PLOT_XSIZE NOT SET, USING DEFAULT OF 700'
    PLOT_XSIZE = CFIG_DATA.(1)[0]
  ENDIF
  IF N_ELEMENTS(PLOT_YSIZE) EQ 0 THEN BEGIN
    PRINT, FCT_NAME+': PLOT_YSIZE NOT SET, USING DEFAULT OF 400'
    PLOT_YSIZE = CFIG_DATA.(1)[1]
  ENDIF  

;------------------------------------------------
; IF ENDIAN SIZE NOT PROVIDED THEN GET VALUE

  IF N_ELEMENTS(ENDIAN_SIZE) EQ 0 THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': NO ENDIAN SIZE PROVIDED, RETRIEVING...'
    ENDIAN_SIZE = GET_ENDIAN_SIZE(VERBOSE=VERBOSE)
  ENDIF

;------------------------
; DEFINE OUTPUT

  OUTPUT_SAV     = STRING(INPUT_FOLDER+DELIM+'Site_'+IREGION+DELIM+SENSOR+DELIM+'Proc_'+IPROC+DELIM+SENSOR+'_TOA_REF.dat')
  OUTPUT_SAV_PIX = STRING(INPUT_FOLDER+DELIM+'Site_'+IREGION+DELIM+SENSOR+DELIM+'Proc_'+IPROC+DELIM+SENSOR+'_TOA_REF_PIX.dat')
  NCDF_FILENAME  = STRING(INPUT_FOLDER+DELIM+'Site_'+IREGION+DELIM+SENSOR+DELIM+'Proc_'+IPROC+DELIM+IREGION+'_'+SENSOR+'_Proc_'+IPROC+'.nc')

;------------------------
; GET NUMBER OF IFILES 

  NB_FILES = N_ELEMENTS(IFILES)

;-----------------------------------------------
; GET THE DATABASE STRUCTURE

  DB_DATA = GET_DIMITRI_TEMPLATE(NB_FILES,/DB)
  
;-----------------------------------------------  
; ADD DATA OF INGESTION TO DB_DATA - NEEDS REWORKING INTO YYYYMMDD

  TEMP = SYSTIME()
  TEMP = STRMATCH(STRMID(TEMP,8,1),' ') ? '0'+STRUPCASE(STRING(STRMID(TEMP,9,1)+'-'+STRMID(TEMP,4,3)+'-'+STRMID(TEMP,20,4))) : STRUPCASE(STRING( STRMID(TEMP,8,2)+'-'+STRMID(TEMP,4,3)+'-'+STRMID(TEMP,20,4)))
  DB_DATA.DIMITRI_DATE = TEMP 

;-----------------------------------------------
; ADD REGION, SENSOR AND PROC VERSION TO DB_DATA

  DB_DATA.REGION = IREGION
  DB_DATA.SENSOR = SENSOR
  DB_DATA.PROCESSING_VERSION = IPROC

;----------------------------------
; DEFINE MERIS SPECIFIC PARAMETERS 

  NB_BANDS = 15
  FNAME_STR = 'MER_RR__1'
  NB_DIRS = SENSOR_DIRECTION_INFO(SENSOR)

;----------------------------------
; DEFINE THE STATISTICAL ARRAYS

  GOOD_RECORD     = MAKE_ARRAY(NB_FILES,/INTEGER,VALUE=0)
  IFILE_DATE 	  = DBLARR(5);CONTAINS YEAR,MONTH,DAY,DOY,DECIMEL_YEAR
  IFILE_VIEW 	  = DBLARR(4);CONTAINS SENSOR ZENITH,SENSOR AZIMUTH,SOLAR ZENITH,SOLAR AZIMUTH
  IFILE_AUX       = DBLARR(12);CONTAINS OZONE,PRESSURE,RELHUMIDITY,WIND_ZONAL,WIND_MERID, AND WVAP (MU AND SIGMA)
  
  IF KEYWORD_SET(VERBOSE) THEN BEGIN
    PRINT, FCT_NAME+': DEFINITION OF OUTPUT ARRAYS:'
    HELP, GOOD_RECORD,IFILE_DATE,IFILE_VIEW
  ENDIF

;---------------------------------
; INITIALISE THE IDL OUTPUT STRUCTURE

  SENSOR_L1B_REF     = [] 
  SENSOR_L1B_REF_PIX = [] 

;---------------------------------
; ADD DATA TO NETCDF OUTPUT STRUCTURE

  NCDF_OUT = GET_DIMITRI_EXTRACT_NCDF_DATA_STRUCTURE(NB_FILES,NB_BANDS,NB_DIRS)
  NCDF_OUT.ATT_FNAME  = 'Site_'+IREGION+'_'+SENSOR+'_'+'Proc_'+IPROC+'.nc'
  NCDF_OUT.ATT_TOOL   = GET_DIMITRI_LOCATION('TOOL')
  NCDF_OUT.ATT_SENSOR = SENSOR
  NCDF_OUT.ATT_PROCV  = IPROC
  NCDF_OUT.ATT_PRES   = STRTRIM(STRING(SENSOR_PIXEL_SIZE(SENSOR)),2)+' KM'
  NCDF_OUT.ATT_NBANDS = STRTRIM(STRING(NB_BANDS),2)
  NCDF_OUT.ATT_NDIRS  = STRTRIM(STRING(NB_DIRS[0]),2)
  NCDF_OUT.ATT_SITEN  = IREGION
  NCDF_OUT.ATT_SITEC  = STRJOIN(STRTRIM(STRING(ICOORDS),2),' ')
  NCDF_OUT.ATT_SITET  = MER_SITE_TYPE

;----------------------------------
; START MAIN LOOP OVER EACH IFILE
  
  IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': STARTING INGESTION LOOP ON MERIS PRODUCTS'
  FOR IN_FNAME=0,NB_FILES-1 DO BEGIN; IN_FNAME IS RESERVED FOR LOOPS WITHIN THE INGESTION ROUTINES

    TEMP = STRSPLIT(IFILES[IN_FNAME],DELIM,/EXTRACT)
    DB_DATA.FILENAME[IN_FNAME] = TEMP[N_ELEMENTS(TEMP)-1] 

;------------------------------------------
; GENERATE AN RGB QUICKLOOK WITH THE ROI OVERLAID
  
    IF N_ELEMENTS(NO_QUICKLOOK) EQ 0 THEN BEGIN
      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': GENERATE QUICKLOOK OF PRODUCT'
        IF FIX(CFIG_DATA.(1)[3]) EQ 1 THEN QL_STATUS =  GET_MERIS_QUICKLOOK(IFILES[IN_FNAME],/ROI,/RGB,ICOORDS=ICOORDS,QL_QUALITY=QL_QUALITY,ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE) $
          ELSE QL_STATUS =  GET_MERIS_QUICKLOOK(IFILES[IN_FNAME],/ROI,ICOORDS=ICOORDS,QL_QUALITY=QL_QUALITY,ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
      
      IF KEYWORD_SET(VERBOSE) THEN IF QL_STATUS EQ -1 THEN PRINT, FCT_NAME+': QUICKLOOK GENERATION FAILED - ',IFILES[IN_FNAME] $
        ELSE PRINT, FCT_NAME+': QUICKLOOK GENERATION SUCCESS' 
    ENDIF 

;-----------------------------------------
; ALLOCATE AVERAGED ARRAYS

    ROI_AVG_TOA_REF = FLTARR(NB_BANDS)
    ROI_STD_TOA_REF = FLTARR(NB_BANDS)

;------------------------------------------
; RETRIEVE AUX DATA FILENAMES FOR DB_DATA

    TEMP = GET_MERIS_AUX_FILES(IFILES[IN_FNAME],VERBOSE=VERBOSE)	

	DB_DATA.AUX_DATA_1[IN_FNAME] = TEMP[0]
	DB_DATA.AUX_DATA_2[IN_FNAME] = TEMP[1] 
	DB_DATA.AUX_DATA_3[IN_FNAME] = TEMP[2] 
	DB_DATA.AUX_DATA_4[IN_FNAME] = TEMP[3] 
	DB_DATA.AUX_DATA_5[IN_FNAME] = TEMP[4] 
	DB_DATA.AUX_DATA_6[IN_FNAME] = TEMP[5] 
	DB_DATA.AUX_DATA_7[IN_FNAME] = TEMP[6] 
	DB_DATA.AUX_DATA_8[IN_FNAME] = TEMP[7] 
	DB_DATA.AUX_DATA_9[IN_FNAME] = TEMP[8] 
	DB_DATA.AUX_DATA_10[IN_FNAME] = TEMP[9] 
        
;----------------------------------
; RETRIEVE DATE INFORMATION

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING DATE INFORMATION'
    STR_POS 		            = STRPOS(IFILES[IN_FNAME],FNAME_STR, /REVERSE_SEARCH)
    IFILE_DATE[0]	= STRMID(IFILES[IN_FNAME],STR_POS+14,4)
    IFILE_DATE[1]	= STRMID(IFILES[IN_FNAME],STR_POS+18,2)
    IFILE_DATE[2]	= STRMID(IFILES[IN_FNAME],STR_POS+20,2)
    
    DATE_HR  = STRMID(IFILES[IN_FNAME],STR_POS+23,2) 
    DATE_MIN = STRMID(IFILES[IN_FNAME],STR_POS+25,2) 
    DATE_SEC = STRMID(IFILES[IN_FNAME],STR_POS+27,2) 
 
    IF FLOAT(IFILE_DATE[0]) MOD 4 EQ 0 THEN DIY = 366.0 ELSE DIY = 365.0
   
    THR = FLOAT(STRMID(IFILES[IN_FNAME],STR_POS+23,2))
    TMM = FLOAT(STRMID(IFILES[IN_FNAME],STR_POS+25,2))
    TSS = FLOAT(STRMID(IFILES[IN_FNAME],STR_POS+27,2))
    TTIME = DOUBLE((THR/(DIY*24.))+(TMM/(DIY*60.*24.))+TSS/(DIY*60.*60.*24.)) 
 
    IFILE_DATE[3]  = JULDAY(IFILE_DATE[1],IFILE_DATE[2],IFILE_DATE[0])-JULDAY(1,0,IFILE_DATE[0])
    IFILE_DATE[4]  = double(IFILE_DATE[0])+(DOUBLE(IFILE_DATE[3])/DIY)+TTIME

;----------------------------------
; ADD DATE INFORMATION TO DB_DATA

    DB_DATA.YEAR[IN_FNAME]  = IFILE_DATE[0]
    DB_DATA.MONTH[IN_FNAME] = IFILE_DATE[1]
    DB_DATA.DAY[IN_FNAME]   = IFILE_DATE[2]
    DB_DATA.DOY[IN_FNAME]   = IFILE_DATE[3]
    DB_DATA.DECIMAL_YEAR[IN_FNAME] = IFILE_DATE[4]
	
;----------------------------------
; RETRIEVE INPUT FILE GEOLOCATION AND VIEWING GEOMETRY

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING GEOLOCATION INFORMATION'
    IFILE_GEO = GET_MERIS_LAT_LON(IFILES[IN_FNAME],ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
    TEMP = GET_MERIS_VIEWING_GEOMETRIES(IFILES[IN_FNAME],ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
    TEMP_ANGLES = DIMITRI_ANGLE_CORRECTOR(TEMP.VZA,TEMP.VAA,TEMP.SZA,TEMP.SAA)
    TEMP=0

;----------------------------------
; CORRECT LON AND LAT ALTITUDE

    RES = WHERE(TEMP_ANGLES.VAA GE 0. AND TEMP_ANGLES.VAA LT 180.,COUNT,COMPLEMENT=RSIGN,NCOMPLEMENT=RCOUNT)
    IF COUNT  GT 0 THEN IFILE_GEO.LON_CORR[RES]     =  1*ABS(IFILE_GEO.LON_CORR[RES])
    IF RCOUNT GT 0 THEN IFILE_GEO.LON_CORR[RSIGN]   = -1*ABS(IFILE_GEO.LON_CORR[RSIGN])
    LAT = IFILE_GEO.LAT+IFILE_GEO.LAT_CORR
    LON = IFILE_GEO.LON+IFILE_GEO.LON_CORR
    IFILE_GEO = 0
    
;----------------------------------
; RETRIEVE INPUT FILE L1B RADIANCE - BASE PIXEL VALIDITY ON B412

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING RADIANCE INFORMATION'
    IFILE_TOA = GET_MERIS_L1B_RADIANCE(IFILES[IN_FNAME],0,ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
    
;------------------------------------------
; RETRIEVE INDEX OF NOMINAL DATA WITHIN ROI

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING INDEX OF PIXELS WITHIN ROI'
    ROI_INDEX = WHERE($
		  	LAT LE ICOORDS[0] AND $
		  	LAT GE ICOORDS[1] AND $
		  	LON LE ICOORDS[2] AND $
		  	LON GE ICOORDS[3] AND $
		  	IFILE_TOA GT 0.0  , $
		  	NB_PIX $
		  	)
	  	
    DB_DATA.NUM_ROI_PX[IN_FNAME] = NB_PIX	

;-----------------------------------------
; SET INITIAL VALUES OF CLOUD SCREENING

    DB_DATA.AUTO_CS[IN_FNAME] = -1.0
    DB_DATA.MANUAL_CS[IN_FNAME] = -1

;-----------------------------------------
; STORE DATE IN NETCDF STRUCTURE

    NCDF_OUT.VAR_PNAME[IN_FNAME]  = DB_DATA.FILENAME[IN_FNAME] 
    NCDF_OUT.VAR_PTIME[IN_FNAME]  = STRMID(IFILES[IN_FNAME],STR_POS+14,8)+' '+DATE_HR+':'+DATE_MIN+':'+DATE_SEC
    NCDF_OUT.VAR_DTIME[IN_FNAME]  = DB_DATA.DECIMAL_YEAR[IN_FNAME]

;-----------------------------------------
; IF NUMBER OF PIXELS IN ROI LESS THAN 
; DEFINED THRESHOLD THEN DO NOT RETRIEVE 
; TOA REFLECTANCE

    IF ROI_INDEX[0] EQ -1 OR NB_PIX LT 5 THEN BEGIN
      DB_DATA.NUM_ROI_PX[IN_FNAME] = -1
      IFILE_VIEW[*]      = BADVAL
      IFILE_AUX[*]       = BADVAL
      ROI_AVG_TOA_REF[*] = BADVAL
      ROI_STD_TOA_REF[*] = BADVAL

      VZA                = BADVAL
      VAA                = BADVAL
      SZA                = BADVAL
      SAA                = BADVAL

      OZONE              = BADVAL
      PRESSURE           = BADVAL
      HUMIDITY           = BADVAL
      WIND               = {ZONAL: BADVAL, MERID: BADVAL}
      VAPOUR             = BADVAL

      TOA_REF            = MAKE_ARRAY(NB_BANDS, /FLOAT, VALUE=BADVAL)

      NB_PIX = 1
      GOTO, NO_ROI
    ENDIF

;-----------------------------------------
; CHECK ROI COVERAGE

    IF DB_DATA.NUM_ROI_PX[IN_FNAME] GT 0 THEN BEGIN
      TROI = CHECK_ROI_COVERAGE(LAT,LON,ROI_INDEX,ICOORDS,VERBOSE=VERBOSE)
      IF TROI GT DB_DATA.ROI_COVER[IN_FNAME] THEN DB_DATA.ROI_COVER[IN_FNAME]=TROI
    ENDIF
		
    GOOD_RECORD[IN_FNAME]=1
    TEMP_AUTO_CS = -1.0
    CS_RHO = MAKE_ARRAY(NB_PIX,NB_BANDS)
    CS_GEO = MAKE_ARRAY(NB_PIX,4)
    
;-----------------------------------------
; LIMIT VIEWING GEOMETRY TO ROI INDEX

    VZA = TEMP_ANGLES.VZA[ROI_INDEX]
    VAA = TEMP_ANGLES.VAA[ROI_INDEX]
    SZA = TEMP_ANGLES.SZA[ROI_INDEX]
    SAA = TEMP_ANGLES.SAA[ROI_INDEX]
    TEMP_ANGLES=0

;------------------------------------------
; COMPUTE MEAN OF VIEWING GEOMETRIES

    IFILE_VIEW[0]=MEAN(VZA)
    IFILE_VIEW[1]=MEAN(VAA)
    IFILE_VIEW[2]=MEAN(SZA)
    IFILE_VIEW[3]=MEAN(SAA)
        
;---------------------------------------
; RETRIEVE THE AUXILIARY INFORMATION
; AND COMPUTE MEAN AND STDEV

    OZONE = GET_MERIS_ECMWF_OZONE(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    OZONE = OZONE[ROI_INDEX]
    IFILE_AUX[0] = MEAN(OZONE)
    IFILE_AUX[1] = STDEV(OZONE)
  
    PRESSURE = GET_MERIS_ECMWF_PRESSURE(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    PRESSURE = PRESSURE[ROI_INDEX]
    IFILE_AUX[2] = MEAN(PRESSURE)
    IFILE_AUX[3] = STDEV(PRESSURE)
  
    HUMIDITY = GET_MERIS_ECMWF_HUMIDITY(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    HUMIDITY = HUMIDITY[ROI_INDEX]
    IFILE_AUX[4] = MEAN(HUMIDITY)
    IFILE_AUX[5] = STDEV(HUMIDITY)
  
    WIND = GET_MERIS_ECMWF_WIND(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    WIND = {ZONAL: WIND.ZONAL[ROI_INDEX], MERID: WIND.MERID[ROI_INDEX]}
    IFILE_AUX[6] = MEAN(WIND.ZONAL)
    IFILE_AUX[7] = STDEV(WIND.ZONAL)
    IFILE_AUX[8] = MEAN(WIND.MERID)
    IFILE_AUX[9] = STDEV(WIND.MERID)
  
    VAPOUR = MAKE_ARRAY(NB_PIX, /FLOAT, VALUE=BADVAL)
    IFILE_AUX[10] = BADVAL
    IFILE_AUX[11] = BADVAL

;---------------------------------------
; RETRIEVE THE DETECTOR INDEX

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING DETECTOR INDEX'
    CCD_INDEX = GET_MERIS_L1B_DETECTOR_INDEX(IFILES[IN_FNAME],ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
		
    CCD_INDEX = CCD_INDEX[ROI_INDEX]
    CCD_MIN   = MIN(CCD_INDEX,MAX=CCD_MAX)

;---------------------------------------
; RETRIEVE THE SOLAR SPECTRAL FLUX RESPONSE 

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING SOLAR FLUX RESPONSE'
    SOLAR_FLUX_RESPONSE = GET_MERIS_SOLAR_FLUX_RR(VERBOSE=VERBOSE)
    SFR_DIMS  = SIZE(SOLAR_FLUX_RESPONSE)

;----------------------------------------
; RETRIEVE F0 - SOLAR IRRADIANCE

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING SOLAR IRRADIANCE'
    SUN_IRR_F0 = GET_MERIS_L1B_F0(IFILES[IN_FNAME],ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)

;----------------------------------------
; COMPUTE TOA REFLECTANCE FOR EACH BAND 

    IFILE_TOA = 0
    TOA_REF   = FLTARR(NB_BANDS,NB_PIX)

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': STARTING LOOP OVER EACH BAND'
		
    FOR IN_BAND=0,NB_BANDS-1 DO BEGIN

      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING RADIANCE FOR BAND -',IN_BAND
      L_TOA_REF=GET_MERIS_L1B_RADIANCE(IFILES[IN_FNAME],IN_BAND,ENDIAN_SIZE=ENDIAN_SIZE,VERBOSE=VERBOSE)
      L_TOA_REF = L_TOA_REF[ROI_INDEX]
			
;----------------------------------------
; RETRIEVE F0 - SOLAR IRRADIANCE AT IN_BAND

      SUN_IRR_F0_BAND = SUN_IRR_F0[IN_BAND]

;----------------------------------------
; COMPUTE SOLAR IRRADIANCE OVER IMAGE

      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': COMPUTING SOLAR IRRADIANCE OVER IMAGE'
      SUN_IRR = FLTARR(N_ELEMENTS(ROI_INDEX))
      FOR IN_SIRR=CCD_MIN,CCD_MAX DO BEGIN
        TEMP = WHERE(CCD_INDEX EQ IN_SIRR)
        IF TEMP[0] GT -1 THEN BEGIN
          SUN_IRR[TEMP] = SOLAR_FLUX_RESPONSE[IN_BAND+1,IN_SIRR]
        ENDIF
      ENDFOR
	
;----------------------------------------
; CORRECT SOLAR IRRADIANCE FOR EARTH/SUN DISTANCE

      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': CORRECTING SOLAR IRRADIANCE FOR EARTH-SUN DISTANCE'
      SUN_IRR = SUN_IRR*(1.0+0.0167*cos(2.0*!DPI*(IFILE_DATE[3]-3.0)/DIY))^2
      
;----------------------------------------
; COMPUTE TOA REFLETANCE TAKING INTO ACCOUNT OF MERIS DETECTORS 

      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': COMPUTE TOA REFLECTANCE FOR BAND -',IN_BAND

;-----------------------------------------      
; CHANGE 0'S TO 0.0001 TO AVOID ARITHMETIC ERRORS - WILL NOT IMPACT ON ROI AVERAGE REFLECTANCES

      TEMP = WHERE(L_TOA_REF LE 0.0,TCOUNT)
        IF TCOUNT GT 0 THEN L_TOA_REF[TEMP] = 0.0001
      TEMP = WHERE(SUN_IRR LE 0.0,TCOUNT)
        IF TCOUNT GT 0 THEN SUN_IRR[TEMP] = 1000.0     
        
      ;	TOA_REF = L_TOA_REF*SUN_IRR_F0[IN_BAND]/SUN_IRR 
      TOA_REF[IN_BAND,*] = L_TOA_REF*!DPI/COS(SZA*!DTOR)/SUN_IRR ;CORRECTS FOR SMILE EFFECT AND EARTH SUN DISTANCE
     
;-----------------------------------------
; COMPUTE MEAN AND STDDEV OF TOA SIGNAL

      VALID = WHERE(TOA_REF[IN_BAND,*] GT 0.0 AND TOA_REF[IN_BAND,*] LT 5.0,COUNT)
      IF COUNT GT 0 THEN BEGIN
       ROI_AVG_TOA_REF[IN_BAND] = MEAN(TOA_REF[IN_BAND,VALID])
       ROI_STD_TOA_REF[IN_BAND] = STDDEV(TOA_REF[IN_BAND,VALID])
      ENDIF

;-----------------------------------------
; STORE DATA IN NETCDF STRUCTURE

      NCDF_OUT.VAR_VZA[0,IN_FNAME]      = IFILE_VIEW[0]
      NCDF_OUT.VAR_VAA[0,IN_FNAME]      = IFILE_VIEW[1]
      NCDF_OUT.VAR_SZA[0,IN_FNAME]      = IFILE_VIEW[2]
      NCDF_OUT.VAR_SAA[0,IN_FNAME]      = IFILE_VIEW[3]
      NCDF_OUT.VAR_PIX[IN_BAND,IN_FNAME,0]      = COUNT
      NCDF_OUT.VAR_RHOMU[IN_BAND,IN_FNAME,0]    = ROI_AVG_TOA_REF[IN_BAND]
      NCDF_OUT.VAR_RHOSD[IN_BAND,IN_FNAME,0]    = ROI_STD_TOA_REF[IN_BAND]
      NCDF_OUT.VAR_OZONEMU[IN_FNAME]  = IFILE_AUX[0]
      NCDF_OUT.VAR_OZONESD[IN_FNAME]  = IFILE_AUX[1]
      NCDF_OUT.VAR_PRESSMU[IN_FNAME]  = IFILE_AUX[2]
      NCDF_OUT.VAR_PRESSSD[IN_FNAME]  = IFILE_AUX[3]
      NCDF_OUT.VAR_RHUMMU[IN_FNAME]   = IFILE_AUX[4]
      NCDF_OUT.VAR_RHUMSD[IN_FNAME]   = IFILE_AUX[5]
      NCDF_OUT.VAR_ZONALMU[IN_FNAME]  = IFILE_AUX[6]
      NCDF_OUT.VAR_ZONALSD[IN_FNAME]  = IFILE_AUX[7]
      NCDF_OUT.VAR_MERIDMU[IN_FNAME]  = IFILE_AUX[8]
      NCDF_OUT.VAR_MERIDSD[IN_FNAME]  = IFILE_AUX[9]
      NCDF_OUT.VAR_WVAPMU[IN_FNAME]   = IFILE_AUX[10]
      NCDF_OUT.VAR_WVAPSD[IN_FNAME]   = IFILE_AUX[11]

      CS_RHO[*,IN_BAND] = TOA_REF[IN_BAND,*]
  
      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': END OF LOOP ON BAND - ',IN_BAND
    ENDFOR; END OF BAND ANALYSIS

;----------------------------------
; APPLY CLOUD SCREENING

    CS_GEO[*,0] = SZA
    CS_GEO[*,1] = VZA
    CS_GEO[*,2] = SAA
    CS_GEO[*,3] = VAA

    CS_MERIS = DIMITRI_CLOUD_SCREENING(SENSOR,MER_SITE_TYPE,CS_RHO,CS_GEO,'GLOBCARBON',VERBOSE=VERBOSE)
    IF CS_MERIS[0] GT TEMP_AUTO_CS THEN TEMP_AUTO_CS = DOUBLE(CS_MERIS[0])
  
    DB_DATA.AUTO_CS[IN_FNAME]         = TEMP_AUTO_CS
    NCDF_OUT.VAR_CLOUD_AUT[IN_FNAME]  = TEMP_AUTO_CS
    NCDF_OUT.VAR_CLOUD_MAN[IN_FNAME]  = -1
    NCDF_OUT.VAR_ROI[IN_FNAME]        = DB_DATA.ROI_COVER[IN_FNAME]

;----------------------------------
; IF ROI IS NOT WITHIN THE PRODUCT OR THERE ARE TOO FEW PIXELS
    NO_ROI:

;-----------------------------------------
; STORE DATA IN IDL STRUCTURE

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': DEFINING OUTPUT AVERAGED ARRAY'
    LINE = [IFILE_DATE[4], IFILE_VIEW, IFILE_AUX, ROI_AVG_TOA_REF, ROI_STD_TOA_REF] 
    SENSOR_L1B_REF = [ [SENSOR_L1B_REF], [LINE] ]
    
    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': DEFINING OUTPUT PIXEL-BY-PIXEL ARRAY'
    DATE=MAKE_ARRAY(MAX([NB_PIX,1]),/DOUBLE,VALUE=IFILE_DATE[4])
    BLOC = TRANSPOSE([[DATE], [VZA], [VAA], [SZA], [SAA], $
                      [OZONE], [PRESSURE], [HUMIDITY], [WIND.ZONAL], [WIND.MERID], [VAPOUR]])
    SENSOR_L1B_REF_PIX = [ [SENSOR_L1B_REF_PIX],  [BLOC, TOA_REF[*,*]] ]

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': END OF LOOP ON PRODUCT'

 ENDFOR; END OF FILE ANALYSIS

;------------------------------------
; AMEND/SAVE DATA TO SAV FILE 

  IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': AMMENDING DATA TO OUTPUT SAV FILE'
  
  NUM_NON_REF = 5+12
  NB_COLS = NUM_NON_REF+2*(NB_BANDS)
  
  TEMP = FILE_INFO(OUTPUT_SAV)
  IF TEMP.EXISTS EQ 1 THEN BEGIN
    TEMP_NEW = SENSOR_L1B_REF
    IF N_ELEMENTS(TEMP_NEW) EQ NB_COLS THEN TEMP_NEW = REFORM(TEMP_NEW,NB_COLS,NB_FILES)
    RESTORE,OUTPUT_SAV
    TEMP_OLD = SENSOR_L1B_REF
    IF N_ELEMENTS(TEMP_OLD) EQ NB_COLS THEN TEMP_OLD = REFORM(TEMP_OLD,NB_COLS,NB_FILES)
    RES_DIMS = SIZE(TEMP_OLD)
     
    SENSOR_L1B_REF = MAKE_ARRAY(NB_COLS,RES_DIMS[2]+NB_FILES,/DOUBLE)
    SENSOR_L1B_REF[*,0:RES_DIMS[2]-1] = TEMP_OLD
    SENSOR_L1B_REF[*,RES_DIMS[2]:RES_DIMS[2]+NB_FILES-1] = TEMP_NEW
           
  ENDIF
	
  RES = SORT(SENSOR_L1B_REF[0,*])
  SENSOR_L1B_REF = SENSOR_L1B_REF[*,RES]
  SAVE,SENSOR_L1B_REF,FILENAME=OUTPUT_SAV

;------------------------------------
; AMEND/SAVE DATA TO PIXEL-BY-PIXEL SAV FILE 

  IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': AMMENDING DATA TO OUTPUT PIXEL-BY-PIXEL SAV FILE'
  
  NUM_NON_REF = 5+6
  NB_COLS = NUM_NON_REF+NB_BANDS
  
  TEMP = FILE_INFO(OUTPUT_SAV_PIX)
  IF TEMP.EXISTS EQ 1 THEN BEGIN
    TEMP_NEW = SENSOR_L1B_REF_PIX
    IF N_ELEMENTS(TEMP_NEW) EQ NB_COLS THEN TEMP_NEW = REFORM(TEMP_NEW,NB_COLS,/OVERWRITE)
    RES_DIMS_NEW = SIZE(TEMP_NEW)
    RESTORE,OUTPUT_SAV_PIX
    TEMP_OLD = SENSOR_L1B_REF_PIX
    IF N_ELEMENTS(TEMP_OLD) EQ NB_COLS THEN TEMP_OLD = REFORM(TEMP_OLD,NB_COLS,/OVERWRITE)
    RES_DIMS_OLD = SIZE(TEMP_OLD)
     
    SENSOR_L1B_REF_PIX = MAKE_ARRAY(NB_COLS,RES_DIMS_OLD[2]+RES_DIMS_NEW[2],/DOUBLE)
    SENSOR_L1B_REF_PIX[*,0:RES_DIMS_OLD[2]-1] = TEMP_OLD
    SENSOR_L1B_REF_PIX[*,RES_DIMS_OLD[2]:RES_DIMS_OLD[2]+RES_DIMS_NEW[2]-1] = TEMP_NEW
           
  ENDIF
	
  RES = SORT(SENSOR_L1B_REF_PIX[0,*])
  SENSOR_L1B_REF_PIX = SENSOR_L1B_REF_PIX[*,RES]
  SAVE,SENSOR_L1B_REF_PIX,FILENAME=OUTPUT_SAV_PIX

;------------------------------------
; GENERATE PLOTS WITH NEW TIME SERIES DATA

  RES = GET_MERIS_TIMESERIES_PLOTS(OUTPUT_SAV,COLOUR_TABLE=COLOUR_TABLE,PLOT_XSIZE=PLOT_XSIZE,PLOT_YSIZE=PLOT_YSIZE,VERBOSE=VERBOSE)
  
;------------------------------------
; SAVE DATA TO NETCDF FILE

  RES = DIMITRI_INTERFACE_EXTRACT_TOA_NCDF(NCDF_OUT,NCDF_FILENAME)  
    
;------------------------------------
; AMEND DATA TO DATABASE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': SENDING DATA TO UPDATE DATABASE'
  RES = UPDATE_DIMITRI_DATABASE(DB_DATA,/SORT_DB,VERBOSE=VERBOSE)
 
  RETURN,1 
END
