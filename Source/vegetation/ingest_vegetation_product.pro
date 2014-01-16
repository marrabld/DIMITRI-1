;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      INGEST_VEGETATION_PRODUCT       
;* 
;* PURPOSE:
;*      INGESTS VEGETATION L1B DATA INTO DIMITRI DATABASE. MULTIPLE PRODUCT 
;*      EXTRACTION IS AVAILABLE BUT IT EXPECTS ALL FILES TO BE THE SAME REGION/PROCESSING. 
;*      OUTPUTS QUICKLOOK IMAGES, UPDATES DATABASE AND APPENDS DATA TO SAV FILE FOR 
;*      SPECIFIED REGION AND PROCESSING.
;* 
;* CALLING SEQUENCE:
;*      RES = INGEST_VEGETATION_PRODUCT(IFILES)      
;* 
;* INPUTS:
;*      IFILES -  A STRING OR STRING ARRAY OF THE FULL PATH FILENAMES OF PRODUCTS (LOG FILES) 
;*                FOR INGESTION.      
;*
;* KEYWORDS:
;*      INPUT_FOLDER      - A STRING CONTAINING THE FULL PATH OF THE 'INPUT' FOLDER, IF 
;*                          NOT PROVIDED THEN IT IS DERIVED FROM THE FILENAME
;*      ICOORDS           - A FOUR ELEMENT FLOATING-POINT ARRAY CONTAINING THE NORTH, SOUTH, 
;*                          EAST AND WEST COORDINATES OF THE ROI, E.G [50.,45.,10.,0.]
;*      NB_PIX_THRESHOLD  - NUMBER OF PIXELS WITHIN ROI TO BE ACCEPTED
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
;*        16 DEC 2010 - C KENT    - DIMITRI-2 V1.0
;*        20 DEC 2010 - C KENT    - UPDATED COMMENTS AND HEADER INFORMATION
;*        10 JAN 2011 - C KENT    - CHANGED SAVED OUTPUT VARIABLE TO SENSOR_L1B_REF 
;*        12 JAN 2011 - C KENT    - OUTPUT RGB QUICKLOOKS AS DEFUALT, UPDATED OUTPUT DATA 
;*                                  WITH SAA AND VAA (REMOVED RAA)
;*        21 MAR 2011 - C KENT    - MODIFIED FILE DEFINITION TO USE GET_DIMITRI_LOCATION
;*        22 MAR 2011 - C KENT    - ADDED CONFIGURAITON FILE DEPENDENCE
;*        06 APR 2011 - C KENT    - ADD VGT AUTOMATED CLOUD SCREENING
;*        01 JUL 2011 - C KENT    - ADDED ANGLE CORRECTOR
;*        04 JUL 2011 - C KENT    - ADDED AUX INFO TO OUTPUT SAV
;*        08 JUL 2011 - C KENT    - ADDED CATCH ON MISSING BAND DATA   
;*        14 JUL 2011 - C KENT    - UPDATED TIME EXTRACTION SECTION
;*        14 SEP 2011 - C KENT    - UPDATED NETCDF OUTPUT
;*        19 SEP 2011 - C KENT    - FIXED OZONE AND WVAP ARRAY BUG
;*        08 MAR 2012 - C KENT    - ADDED ROI COVERAGE
;*        21 MAR 2012 - C KENT    - ADDED FIX FOR ERRONEOUS VITO D VALUES
;*        09 APR 2012 - C KENT    - IMPLEMENTED CNES CORRECTION FOR VITO REFLECTANCES
;*        02 JAN 2014 - C MAZERAN - CHANGED CODE STRUCTURE TO ADD PIXEL BY PIXEL EXTRACTION
;*
;* VALIDATION HISTORY:
;*        16 DEC 2010 - C KENT    - WINDOWS 32BIT MACHINE, COMPILATION AND EXECUTION 
;*                                  SUCCESSFUL. TESTED MULTIPLE OPTIONS ON MULTIPLE 
;*                                  PRODUCTS
;*        12 APR 2011 - C KENT    - LINUX 64BIT MACHINE IDL 8.0: COMPILATION AND OPERATION SUCCESSFUL 
;*        02 JAN 2014 - C MAZERAN - LINUX 64BIT MACHINE IDL 8.2: COMPILATION AND OPERATION SUCCESSFUL 
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION INGEST_VEGETATION_PRODUCT,IFILES,INPUT_FOLDER=INPUT_FOLDER,ICOORDS=ICOORDS,$
         COLOUR_TABLE=COLOUR_TABLE,$
         PLOT_XSIZE=PLOT_XSIZE,PLOT_YSIZE=PLOT_YSIZE,NO_ZBUFF=NO_ZBUFF,NO_QUICKLOOK=NO_QUICKLOOK,$
         VERBOSE=VERBOSE

;------------------------
; DEFINE CURRENT FUNCTION NAME

  FCT_NAME='INGEST_VEGETATION_PRODUCT'

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
  VGT_SITE_TYPE = GET_SITE_TYPE(IREGION,VERBOSE=VERBOSE) 

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
; ADD DATA OF INGESTION TO DB_DATA

  TEMP = SYSTIME()
  TEMP = STRMATCH(STRMID(TEMP,8,1),' ') ? '0'+STRUPCASE(STRING(STRMID(TEMP,9,1)+'-'+STRMID(TEMP,4,3)+'-'+STRMID(TEMP,20,4))) : STRUPCASE(STRING( STRMID(TEMP,8,2)+'-'+STRMID(TEMP,4,3)+'-'+STRMID(TEMP,20,4)))
  DB_DATA.DIMITRI_DATE = TEMP 

;-----------------------------------------------
; ADD REGION, SENSOR AND PROC VERSION TO DB_DATA

  DB_DATA.REGION = IREGION
  DB_DATA.SENSOR = SENSOR
  DB_DATA.PROCESSING_VERSION = IPROC
 
;----------------------------------
; DEFINE VEGETATION SPECIFIC PARAMETERS 

  NB_BANDS = 4
  NB_DIRS = SENSOR_DIRECTION_INFO(SENSOR)
  
;----------------------------------
; DEFINE THE STATISTICAL ARRAYS

  BADVAL = -999.0
  GOOD_RECORD = MAKE_ARRAY(NB_FILES,/INTEGER,VALUE=0)
  IFILE_DATE  = DBLARR(5);CONTAINS YEAR,MONTH,DAY,DOY,DECIMEL_YEAR
  IFILE_VIEW  = DBLARR(4);CONTAINS SENSOR ZENITH,SENSOR AZIMUTH,SOLAR ZENITH,SOLAR AZIMUTH
  IFILE_AUX   = FLTARR(12);CONTAINS OZONE,PRESSURE,RELHUMIDITY,WIND_ZONAL,WIND_MERID, AND WVAP (MU AND SIGMA)

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
  NCDF_OUT.ATT_SITET  = VGT_SITE_TYPE
 
;----------------------------------
; START MAIN LOOP OVER EACH IFILE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': STARTING INGESTION LOOP ON MERIS PRODUCTS'
  FOR IN_FNAME=0,NB_FILES-1 DO BEGIN; IN_FNAME IS RESERVED FOR LOOPS WITHIN THE INGESTION ROUTINES

    TEMP = STRSPLIT(IFILES[IN_FNAME],DELIM,/EXTRACT)
    TEMP1 = N_ELEMENTS(TEMP)
    DB_DATA.FILENAME[IN_FNAME] = STRJOIN(TEMP[TEMP1-3:TEMP1-1],'_') ;MOVED TO WITHIN FILE LOOP

;-----------------------------------------
; ALLOCATE AVERAGED ARRAYS

    ROI_AVG_TOA_REF = FLTARR(NB_BANDS)
    ROI_STD_TOA_REF = FLTARR(NB_BANDS)

;------------------------------------------
; RETRIEVE AUX DATA FILENAMES FOR DB_DATA

    IF KEYWORD_SET(VERBOSE) THEN PRINT,FCT_NAME+': RETRIEVING HEADER INFORMATION'
    L1B_HEADER = GET_VEGETATION_HEADER_INFO(IFILES[IN_FNAME],VERBOSE=VERBOSE)
       
    TEMP = 'NONE'
    DB_DATA.AUX_DATA_1[IN_FNAME] = L1B_HEADER.PRD_ID
    DB_DATA.AUX_DATA_2[IN_FNAME] = L1B_HEADER.AUX_DEM 
    DB_DATA.AUX_DATA_3[IN_FNAME] = L1B_HEADER.AUX_RAD_EQL 
    DB_DATA.AUX_DATA_4[IN_FNAME] = L1B_HEADER.AUX_RAD_ABS 
    DB_DATA.AUX_DATA_5[IN_FNAME] = L1B_HEADER.AUX_GEO
    DB_DATA.AUX_DATA_6[IN_FNAME] = TEMP 
    DB_DATA.AUX_DATA_7[IN_FNAME] = TEMP 
    DB_DATA.AUX_DATA_8[IN_FNAME] = TEMP 
    DB_DATA.AUX_DATA_9[IN_FNAME] = TEMP 
    DB_DATA.AUX_DATA_10[IN_FNAME] = TEMP 
        
;----------------------------------
; RETRIEVE DATE INFORMATION

    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING DATE INFORMATION'
    IFILE_DATE[0]	= STRMID(L1B_HEADER.ACQ_DATE,0,4)
    IFILE_DATE[1]	= STRMID(L1B_HEADER.ACQ_DATE,4,2)
    IFILE_DATE[2]	= STRMID(L1B_HEADER.ACQ_DATE,6,2)
    IF FLOAT(IFILE_DATE[0]) MOD 4 EQ 0 THEN DIY = 366.0 ELSE DIY = 365.0    
    IFILE_DATE[3]	= JULDAY(IFILE_DATE[1],IFILE_DATE[2],IFILE_DATE[0])-JULDAY(1,0,IFILE_DATE[0])

    THR = FLOAT(STRMID(L1B_HEADER.ACQ_TIME,0,2))
    TMM = FLOAT(STRMID(L1B_HEADER.ACQ_TIME,2,2))
    TSS = FLOAT(STRMID(L1B_HEADER.ACQ_TIME,4,2))
    TTIME = DOUBLE((THR/(DIY*24.))+(TMM/(DIY*60.*24.))+TSS/(DIY*60.*60.*24.))

    IFILE_DATE[4] =  FLOAT(IFILE_DATE[0])+ DOUBLE(IFILE_DATE[3]/DIY)+TTIME

;----------------------------------
; ADD DATE INFORMATION TO DB_DATA

    DB_DATA.YEAR[IN_FNAME]   = IFILE_DATE[0]
    DB_DATA.MONTH[IN_FNAME]  = IFILE_DATE[1]
    DB_DATA.DAY[IN_FNAME]    = IFILE_DATE[2]
    DB_DATA.DOY[IN_FNAME]    = IFILE_DATE[3]
    DB_DATA.DECIMAL_YEAR[IN_FNAME] = IFILE_DATE[4]

;-----------------------------------------
; SET INITIAL VALUES OF CLOUD SCREENING

    DB_DATA.AUTO_CS[IN_FNAME] = -1
    DB_DATA.MANUAL_CS = -1
    
;-----------------------------------------
; STORE DATE IN NETCDF STRUCTURE

    NCDF_OUT.VAR_PNAME[IN_FNAME]  = DB_DATA.FILENAME[IN_FNAME] 
    NCDF_OUT.VAR_PTIME[IN_FNAME]  = STRMID(L1B_HEADER.ACQ_DATE,0,8)+' '+STRMID(L1B_HEADER.ACQ_TIME,0,2)+':'+STRMID(L1B_HEADER.ACQ_TIME,2,2)+':'+STRMID(L1B_HEADER.ACQ_TIME,4,2)
    NCDF_OUT.VAR_DTIME[IN_FNAME]  = DB_DATA.DECIMAL_YEAR[IN_FNAME]

;------------------------------------------
; CHECK THAT THE REFLECTANCE DATA IS PRESENT

    TMP_FILE1 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'B0.HDF')
    TMP_FILE2 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'MIR.HDF')
    TMP_FILE3 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'B2.HDF')
    TMP_FILE4 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'B3.HDF')
    TMP_FILE5 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'VZA.HDF')
    TMP_FILE6 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'VAA.HDF')
    TMP_FILE7 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'SZA.HDF')
    TMP_FILE8 = STRING(STRMID(IFILES[IN_FNAME],0,STRLEN(IFILES[IN_FNAME])-7)+'SAA.HDF')
    

    IF FILE_TEST(TMP_FILE1) EQ 0 or $
    FILE_TEST(TMP_FILE2) EQ 0 or $
    FILE_TEST(TMP_FILE3) EQ 0 or $
    FILE_TEST(TMP_FILE4) EQ 0 or $
    FILE_TEST(TMP_FILE5) EQ 0 or $
    FILE_TEST(TMP_FILE6) EQ 0 or $
    FILE_TEST(TMP_FILE7) EQ 0 or $
    FILE_TEST(TMP_FILE8) EQ 0 THEN GOTO, NO_BAND_DATA

;------------------------------------------
; GENERATE A QUICKLOOK WITH THE ROI OVERLAID
  
    IF N_ELEMENTS(NO_QUICKLOOK) EQ 0 THEN BEGIN
      IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': GENERATE QUICKLOOK OF PRODUCT'
      IF FIX(CFIG_DATA.(1)[3]) EQ 1 THEN QL_STATUS =  GET_VEGETATION_QUICKLOOK(IFILES[IN_FNAME],/ROI,/RGB,ICOORDS=ICOORDS,QL_QUALITY=QL_QUALITY,VERBOSE=VERBOSE) $
         ELSE QL_STATUS =  GET_VEGETATION_QUICKLOOK(IFILES[IN_FNAME],/ROI,ICOORDS=ICOORDS,QL_QUALITY=QL_QUALITY,VERBOSE=VERBOSE)

      IF KEYWORD_SET(VERBOSE) THEN IF QL_STATUS EQ -1 THEN PRINT, FCT_NAME+': QUICKLOOK GENERATION FAILED - ',IFILES[IN_FNAME] $
        ELSE PRINT, FCT_NAME+': QUICKLOOK GENERATION SUCCESS' 
    ENDIF  

;-----------------------------------------
; RETRIEVE PRODUCT DATA
  
    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING GEOLOCATION, REFLECTANCE AND VIEWING GEOMETRIES'
    L1B_GEO = GET_VEGETATION_LAT_LON(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    L1B_REF = GET_VEGETATION_L1B_REFLECTANCE(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    
    IF MAX(L1B_REF[*,*,0]) LT 0.00001 THEN GOTO, NO_BAND_DATA
    L1B_VGEO = GET_VEGETATION_VIEWING_GEOMETRIES(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    TEMP_ANGLES = DIMITRI_ANGLE_CORRECTOR(L1B_VGEO[*,*,2],L1B_VGEO[*,*,3],L1B_VGEO[*,*,0],L1B_VGEO[*,*,1])

;------------------------------------------
; RETRIEVE INDEX OF NOMINAL DATA WITHIN ROI
 
    IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': RETRIEVING INDEX OF PIXELS WITHIN ROI'
    ROI_INDEX = WHERE($
            L1B_GEO.LAT LT ICOORDS[0] AND $
            L1B_GEO.LAT GT ICOORDS[1] AND $
            L1B_GEO.LON LT ICOORDS[2] AND $
            L1B_GEO.LON GT ICOORDS[3] AND $
            L1B_REF[*,*,0] GT 0.0    , $
            NB_PIX $
            )
 
    DB_DATA.NUM_ROI_PX[IN_FNAME] = NB_PIX 
       
;-----------------------------------------
; IF NO PIXELS IN ROI THEN DO NOT RETRIEVE 
; TOA REFLECTANCE

    IF ROI_INDEX[0] EQ -1 THEN BEGIN
      NO_BAND_DATA:
      DB_DATA.NUM_ROI_PX[IN_FNAME] = -1
      IFILE_VIEW[*]= BADVAL
      IFILE_AUX[*] = BADVAL
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
      TROI = CHECK_ROI_COVERAGE(L1B_GEO.LAT,L1B_GEO.LON,ROI_INDEX,ICOORDS,VERBOSE=VERBOSE)
      IF TROI GT DB_DATA.ROI_COVER[IN_FNAME] THEN DB_DATA.ROI_COVER[IN_FNAME]=TROI
    ENDIF

;------------------------------------------
; LIMIT VIEWING/ILLUMINATION GEOMETRIES TO ROI

    VZA = TEMP_ANGLES.VZA[ROI_INDEX]
    VAA = TEMP_ANGLES.VAA[ROI_INDEX]
    SZA = TEMP_ANGLES.SZA[ROI_INDEX]
    SAA = TEMP_ANGLES.SAA[ROI_INDEX]
    TEMP_ANGLES=0    

;------------------------------------------
; COMPUTE MEAN OF GEOMETRIES

    IFILE_VIEW[0] = MEAN(VZA)
    IFILE_VIEW[1] = MEAN(VAA)
    IFILE_VIEW[2] = MEAN(SZA)
    IFILE_VIEW[3] = MEAN(SAA)

;----------------------------------------
; RETRIEVE THE AUXILIARY INFORMATION
; AND COMPUTE MEAN AND STDEV

    OZONE = GET_VEGETATION_OZONE(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    OZONE = 1000.*OZONE[ROI_INDEX]
    IFILE_AUX[0] = MEAN(OZONE)
    IFILE_AUX[1] = STDEV(OZONE) 

    PRESSURE = MAKE_ARRAY(NB_PIX, /FLOAT, VALUE=BADVAL)
    HUMIDITY = MAKE_ARRAY(NB_PIX, /FLOAT, VALUE=BADVAL)
    WIND     = {ZONAL: MAKE_ARRAY(NB_PIX, /FLOAT, VALUE=BADVAL), MERID: MAKE_ARRAY(NB_PIX, /FLOAT, VALUE=BADVAL)}
    IFILE_AUX[2:9] = BADVAL

    VAPOUR = GET_VEGETATION_WVAP(IFILES[IN_FNAME],VERBOSE=VERBOSE)
    VAPOUR = VAPOUR[ROI_INDEX]
    IFILE_AUX[10] = MEAN(VAPOUR)
    IFILE_AUX[11] = STDEV(VAPOUR)     
      
;------------------------------------------
; CREATE ARRAY FOR CLOUD SCREENING RHO 

    CS_REF = MAKE_ARRAY(NB_PIX,NB_BANDS,/FLOAT)

;-----------------------------------------
; STORE DATA IN NETCDF STRUCTURE

    NCDF_OUT.VAR_VZA[0,IN_FNAME]    = IFILE_VIEW[0]
    NCDF_OUT.VAR_VAA[0,IN_FNAME]    = IFILE_VIEW[1]
    NCDF_OUT.VAR_SZA[0,IN_FNAME]    = IFILE_VIEW[2]
    NCDF_OUT.VAR_SAA[0,IN_FNAME]    = IFILE_VIEW[3]

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

;------------------------------------------
; EARTH-SUN FIX FOR VITO VGT DATA - ERRONEOUS D2 VALUE SET ALWAYS TO JAN 1ST

;      JD    = 1+JULDAY(1,1,DB_DATA.YEAR[IN_FNAME])-JULDAY(1,1,1950);JULIAN DAY SINCE 1950
;      T     = JD-10000.
;      D     = ((11.786+12.190749*T) MOD 360.)*!DTOR
;      XLP   = ((134.003+0.9856*T) MOD 360.)*!DTOR
;      DUA   = 1. / (1.+(1672.2*COS(XLP)+28.*COS(2.*XLP)-0.35*COS(D))*1.E-5)
;      DVITO = DUA^2
;      DDIMI = (1.0+0.0167*COS(2.0*!DPI*(DB_DATA.DOY[IN_FNAME]-3.0)/365.))^2
;      DNEW  = DVITO*DDIMI
      
    CF = GET_VGT_CORRECTION_FACTOR(DB_DATA.DOY[IN_FNAME])

;------------------------------------------
; LOOP OVER EACH BAND

    TOA_REF   = FLTARR(NB_BANDS,NB_PIX)

    IF KEYWORD_SET(VERBOSE) THEN PRINT,FCT_NAME+': STARTING LOOP OVER EACH BAND'
    FOR IN_BAND=0,NB_BANDS-1 DO BEGIN
      
      TEMP_REF = L1B_REF[*,*,IN_BAND]*CF;/DNEW
      TOA_REF[IN_BAND,*] = TEMP_REF[ROI_INDEX]
      
;-----------------------------------------
; COMPUTE MEAN AND STDDEV OF TOA SIGNAL
      
      VALID = WHERE(TOA_REF[IN_BAND,*] GT 0.0 AND TOA_REF[IN_BAND,*] LT 5.0,COUNT)
      IF VALID[0] GT -1 THEN BEGIN
        ROI_AVG_TOA_REF[IN_BAND] = MEAN(TOA_REF[IN_BAND,VALID])
        ROI_STD_TOA_REF[IN_BAND] = STDDEV(TOA_REF[IN_BAND,VALID])
        NCDF_OUT.VAR_PIX[IN_BAND,IN_FNAME,0]   = COUNT
        NCDF_OUT.VAR_RHOMU[IN_BAND,IN_FNAME,0] = ROI_AVG_TOA_REF[IN_BAND]
        NCDF_OUT.VAR_RHOSD[IN_BAND,IN_FNAME,0] = ROI_STD_TOA_REF[IN_BAND]
      ENDIF
      
      CS_REF[*,IN_BAND] = TOA_REF[IN_BAND,*]
      
    ENDFOR;END OF LOOP ON BANDS
 
 ;----------------------------------
 ; APPLY CLOUD SCREENING
 
    CLOUD_MASK = DIMITRI_CLOUD_SCREENING(SENSOR,VGT_SITE_TYPE,CS_REF,0,'VGT')

;--------------------------
; CALCULATE PERCENTAGE CLOUD

    VALID_PIXELS = WHERE(CS_REF[*,0] GT 0.0,NUM_PIX)
    CS_MASK      = WHERE(CLOUD_MASK EQ 1,NUM_CS)
    CS_VGT       = FLOAT(NUM_CS)/FLOAT(NUM_PIX)

    DB_DATA.AUTO_CS[IN_FNAME] = CS_VGT
    NCDF_OUT.VAR_CLOUD_AUT[IN_FNAME]  = CS_VGT
    NCDF_OUT.VAR_CLOUD_MAN[IN_FNAME]  = -1
    NCDF_OUT.VAR_ROI[IN_FNAME]        = DB_DATA.ROI_COVER[IN_FNAME]

;----------------------------------
; IF ROI IS NOT WITHIN THE PRODUCT
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

  RES = GET_VEGETATION_TIMESERIES_PLOTS(OUTPUT_SAV,COLOUR_TABLE=COLOUR_TABLE,PLOT_XSIZE=PLOT_XSIZE,PLOT_YSIZE=PLOT_YSIZE,VERBOSE=VERBOSE) 

;------------------------------------
; SAVE DATA TO NETCDF FILE

  RES = DIMITRI_INTERFACE_EXTRACT_TOA_NCDF(NCDF_OUT,NCDF_FILENAME)  

;------------------------------------
; AMEND DATA TO DATABASE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, FCT_NAME+': SENDING DATA TO UPDATE DATABASE'
  RES = UPDATE_DIMITRI_DATABASE(DB_DATA,/SORT_DB,VERBOSE=VERBOSE) 
 
  RETURN,1 
END
