;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      DHMI_VISU    
;* 
;* PURPOSE:
;*      THIS PROGRAM DISPLAYS A WIDGET ALLOWING SPECIFICATION OF THE REQUIRED PARAMETERS 
;*      TO START THE VISUALISATION OBJET GRAPHICS INTERFACE. USER'S ARE REQUESTED TO 
;*      PROVIDE THE OUTPUTFOLDER, SITE, REFERENCE SENSOR, REFERENCE PROCESSING VERSION
;*      AND DIMITRI BAND. 
;*
;* CALLING SEQUENCE:
;*      DHMI_VISU      
;*
;* INPUTS:
;*      NONE
;*
;* KEYWORDS:
;*      GROUP_LEADER - THE ID OF ANOTHER WIDGET TO BE USED AS THE GROUP LEADER
;*      VERBOSE      - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      NONE
;*
;* COMMON BLOCKS:
;*      DHMI_DATABASE - CONTAINS THE DATABASE DATA FOR THE DIMITRI HMI
;*
;* MODIFICATION HISTORY:
;*      08 MAR 2011 - C KENT    - DIMITRI-2 V1.0
;*      21 MAR 2011 - C KENT    - MODIFIED FILE DEFINITION TO USE GET_DIMITRI_LOCATION
;*      06 JUL 2011 - C KENT    - ADDED DATABASE COMMON BLOCK TO DIMITRI HMI
;*
;* VALIDATION HISTORY:
;*      14 APR 2011 - C KENT    - WINDOWS 32-BIT IDL 7.1 AND LINUX 64-BIT IDL 8.0 NOMINAL
;*                                COMPILATION AND OPERATION       
;*
;**************************************************************************************
;**************************************************************************************

PRO DHMI_VISU_DROPLIST,EVENT

;--------------------------
; CATCH THE DROPLIST EVENT 
; AND DO NOTHING
  
  WIDGET_CONTROL, EVENT.TOP, GET_UVALUE=DHMI_VISU_INFO, /NO_COPY
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_VISU_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_VISU_EXIT,EVENT

;--------------------------
; GET EVENT AND WIDGET INFO

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_VISU_INFO, /NO_COPY
  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN $
    PRINT,'DHMI_VISU: FINDING AVAILABLE SENSORS WITHIN SITE AND OUTPUTFOLDER'

;--------------------------
; CLEAN UP OBJECTS

  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->EXIT: DESTROYING ALL OBJECTS'
  OBJ_DESTROY,DHMI_VISU_INFO.FSCOUTF
  OBJ_DESTROY,DHMI_VISU_INFO.FSCSITE
  OBJ_DESTROY,DHMI_VISU_INFO.FSCSENS
  OBJ_DESTROY,DHMI_VISU_INFO.FSCPROC

;--------------------------
; DESTROY THE WIDGET

  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->EXIT: DESTROYING THE WIDGET'
  WIDGET_CONTROL,EVENT.TOP,/DESTROY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_VISU_START,EVENT

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_VISU_INFO, /NO_COPY

;--------------------------
; GET REQUIRED VALUES FROM WIDGET

  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->START: RETRIEVING REQUIRED VALUES FROM WIDGET'
  DHMI_VISU_INFO.FSCOUTF->GETPROPERTY,VALUE=VISU_OUTPUT_FOLDER
  DHMI_VISU_INFO.FSCSITE->GETPROPERTY,VALUE=VISU_SITE
  DHMI_VISU_INFO.FSCSENS->GETPROPERTY,VALUE=VISU_SENSOR
  DHMI_VISU_INFO.FSCPROC->GETPROPERTY,VALUE=VISU_PROCV

  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->START: SETTING OUTPUT FOLDER AND DROPLIST VALUES'
  VISU_OUTPUT_FOLDER  = DHMI_VISU_INFO.VISU_OFOLDER+DHMI_VISU_INFO.DL+VISU_OUTPUT_FOLDER
  TEMP                = WIDGET_INFO(DHMI_VISU_INFO.DROPID, /DROPLIST_SELECT)
  WIDGET_CONTROL, DHMI_VISU_INFO.DROPID, GET_UVALUE=DROPLIST
  VISU_BAND           = DROPLIST[TEMP]
  
  RES       = STRPOS(VISU_BAND,' nm')
  VISU_BAND = STRMID(VISU_BAND,3,STRLEN(VISU_BAND)-6)
  VISU_BAND = CONVERT_WAVELENGTH_TO_DINDEX(VISU_BAND)+1

;--------------------------
; GET SCREEN DIMENSIONS FOR 
; CENTERING WIDGET

  DIMS  = GET_SCREEN_SIZE()
  XSIZE = 200
  YSIZE = 60
  XLOC  = (DIMS[0]/2)-(XSIZE/2)
  YLOC  = (DIMS[1]/2)-(YSIZE/2)
  
;--------------------------
; CREATE A POP WIDGET AND START 
; THE VISUALISATION INTERFACE

  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->START: CREATING A POP WIDGET '
  INFO_WD = WIDGET_BASE(COLUMN=1, XSIZE=XSIZE, YSIZE=YSIZE, TITLE='Please Wait...',XOFFSET=XLOC,YOFFSET=YLOC)
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE=' ')
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE='Please wait,')
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE='Loading in progress...')
  WIDGET_CONTROL, INFO_WD, /REALIZE
  WIDGET_CONTROL, /HOURGLASS
  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN BEGIN
    PRINT,'DHMI_VISU->START: CALLING THE VISUALISATION ROUTINE'  
    DIMITRI_VISUALISATION,VISU_OUTPUT_FOLDER,VISU_SITE,VISU_BAND,$
                          VISU_SENSOR,VISU_PROCV,GROUP_LEADER=EVENT.TOP,/VERBOSE
  ENDIF ELSE DIMITRI_VISUALISATION,VISU_OUTPUT_FOLDER,VISU_SITE,VISU_BAND,$
                                   VISU_SENSOR,VISU_PROCV,GROUP_LEADER=EVENT.TOP

  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->START: DESTROYING THE POP WIDGET'    
  WIDGET_CONTROL,INFO_WD,/DESTROY
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_VISU_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_VISU_CHANGE,EVENT

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_VISU_INFO, /NO_COPY
  WIDGET_CONTROL, EVENT.ID,   GET_UVALUE=ACTION

;--------------------------
; GET THE ACTION TYPE

  ACTION_TYPE = STRMID(ACTION,0,1)

;--------------------------
; DEPENDING ON ACTION TYPE 
; PERFORM DIFFERENT SECTIONS 
; OF THE PROGRAM

;--------------------------
; MODIFY THE OUTPUT FOLDER 
; AND SUBSEQUENT FIELDS

  IF ACTION_TYPE EQ 'O' THEN BEGIN
  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->CHANGE: CHANGING OUTPUT FOLDER'
    IF DHMI_VISU_INFO.NOUTFS EQ 1 THEN GOTO, NO_CHANGE_OUTF
    CASE ACTION OF
      'OUTF<':DHMI_VISU_INFO.IOUTF = DHMI_VISU_INFO.IOUTF-1
      'OUTF>':DHMI_VISU_INFO.IOUTF = DHMI_VISU_INFO.IOUTF+1
    ENDCASE
    IF DHMI_VISU_INFO.IOUTF LT 0 THEN DHMI_VISU_INFO.IOUTF = DHMI_VISU_INFO.NOUTFS-1
    IF DHMI_VISU_INFO.IOUTF EQ DHMI_VISU_INFO.NOUTFS THEN DHMI_VISU_INFO.IOUTF = 0     
    DHMI_VISU_INFO.FSCOUTF->SETPROPERTY, VALUE=DHMI_VISU_INFO.AOUTF[DHMI_VISU_INFO.IOUTF] 
    TMP_IOUTF = DHMI_VISU_INFO.IOUTF 
    GOTO, NO_CHANGE_OUTF

;--------------------------
; UPDATE LIST OF AVAILABLE SITES

   IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->CHANGE: CHANGING AVAILABLE SITES'
    NASITE=0
    FOR I=0,DHMI_VISU_INFO.NSITES-1 DO BEGIN 
      RES = TOTAL(DHMI_VISU_INFO.DATA_AVBLE[*,*,I,DHMI_VISU_INFO.IOUTF])
      IF RES GT 0 THEN BEGIN
        DHMI_VISU_INFO.ASITES[NASITE]=DHMI_VISU_INFO.USITES[I]
        NASITE++
      ENDIF
    ENDFOR

    DHMI_VISU_INFO.ISITE = 0
    DHMI_VISU_INFO.NASITE = NASITE
    DHMI_VISU_INFO.FSCSITE->SETPROPERTY, VALUE=DHMI_VISU_INFO.ASITES[0]

;--------------------------
; UPDATE SENSORS AND PROC_VERS 
        
    GOTO, UPDATE_SENS_VALUES
    NO_CHANGE_OUTF:
  ENDIF

;--------------------------
; MODIFY THE REGION 
; AND SUBSEQUENT FIELDS

  IF ACTION_TYPE EQ 'R' THEN BEGIN
  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->CHANGE: CHANGING REGION SELECTED'
    IF DHMI_VISU_INFO.NASITE EQ 1 THEN GOTO, NO_CHANGE_SITE
    CASE ACTION OF
      'RSITE<':DHMI_VISU_INFO.ISITE = DHMI_VISU_INFO.ISITE-1
      'RSITE>':DHMI_VISU_INFO.ISITE = DHMI_VISU_INFO.ISITE+1
    ENDCASE
    IF DHMI_VISU_INFO.ISITE LT 0 THEN DHMI_VISU_INFO.ISITE = DHMI_VISU_INFO.NASITE-1
    IF DHMI_VISU_INFO.ISITE EQ DHMI_VISU_INFO.NASITE THEN DHMI_VISU_INFO.ISITE = 0
    DHMI_VISU_INFO.FSCSITE->SETPROPERTY, VALUE=DHMI_VISU_INFO.ASITES[DHMI_VISU_INFO.ISITE]
    GOTO, NO_CHANGE_SITE

;--------------------------
; UPDATE LIST OF AVAILABLE SENSORS

    UPDATE_SENS_VALUES:
    IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->CHANGE: CHANGING AVAILABLE SENSORS'
    TMP_ISITE = WHERE(DHMI_VISU_INFO.USITES EQ DHMI_VISU_INFO.ASITES[DHMI_VISU_INFO.ISITE])
    NASENS = 0
    FOR I=0,N_ELEMENTS(DHMI_VISU_INFO.USENSS)-1 DO BEGIN
      IF TOTAL(DHMI_VISU_INFO.DATA_AVBLE[*,I,TMP_ISITE,DHMI_VISU_INFO.IOUTF]) GE 1 THEN BEGIN
        DHMI_VISU_INFO.ASENSS[NASENS] = DHMI_VISU_INFO.USENSS[I]
        NASENS++ 
      ENDIF
    ENDFOR     
    DHMI_VISU_INFO.ISENS = 0
    DHMI_VISU_INFO.NASENS = NASENS     
    DHMI_VISU_INFO.FSCSENS->SETPROPERTY, VALUE=DHMI_VISU_INFO.ASENSS[0]

;--------------------------
; UPDATE LIST OF AVAILABLE PROC VERSIONS

    GOTO,UPDATE_PROC_VALUES 
    NO_CHANGE_SITE:
  ENDIF

;--------------------------
; MODIFY THE SENSOR
; AND SUBSEQUENT FIELDS

  IF ACTION_TYPE EQ 'S' THEN BEGIN
  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->CHANGE: CHANGING SENSOR SELECTED'
    ;IF DHMI_VISU_INFO.NASENS EQ 1 THEN GOTO, NO_CHANGE_SENS
    CASE ACTION OF
      'SENSOR<':DHMI_VISU_INFO.ISENS = DHMI_VISU_INFO.ISENS-1
      'SENSOR>':DHMI_VISU_INFO.ISENS = DHMI_VISU_INFO.ISENS+1
    ENDCASE
    IF DHMI_VISU_INFO.ISENS LT 0 THEN DHMI_VISU_INFO.ISENS = DHMI_VISU_INFO.NASENS-1
    IF DHMI_VISU_INFO.ISENS EQ DHMI_VISU_INFO.NASENS THEN DHMI_VISU_INFO.ISENS = 0

;--------------------------
; UPDATE LIST OF AVAILABLE PROC VERSIONS

    UPDATE_PROC_VALUES:
    IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN $
      PRINT,'DHMI_VISU->CHANGE: CHANGING AVAILABLE PROCESSING VERSIONS'
    TMP_ISENS = WHERE(DHMI_VISU_INFO.USENSS EQ DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS])
    TMP_ISITE = WHERE(DHMI_VISU_INFO.USITES EQ DHMI_VISU_INFO.ASITES[DHMI_VISU_INFO.ISITE])
       
    RES = WHERE(DHMI_VISU_INFO.DATA_AVBLE[*,TMP_ISENS,TMP_ISITE,DHMI_VISU_INFO.IOUTF] EQ 1,COUNT)
    IF COUNT EQ 0 THEN DHMI_VISU_INFO.APROC[*] = 'N/A' ELSE $
    DHMI_VISU_INFO.APROC[0:COUNT-1] = DHMI_VISU_INFO.UPROCV[RES]
    DHMI_VISU_INFO.NAPROC=COUNT
    DHMI_VISU_INFO.IPROC = 0

;--------------------------
; UPDATE LIST OF AVAILABLE DIMITRI BANDS

    IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN $
      PRINT,'DHMI_VISU->CHANGE: UPDATING LIST OF AVAILABLE DIMITRI BANDS'       
    
;-----------------------------------------
; RETRIEVE THE SITE TYPE

    SITE_TYPE = GET_SITE_TYPE(DHMI_VISU_INFO.ASITES[DHMI_VISU_INFO.ISITE]) 

;-----------------------------------------
; MODISA SURFACE DEPENDANCE EXCEPTION

    IF DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS] EQ 'MODISA' THEN BEGIN
      IF STRUPCASE(SITE_TYPE) EQ 'OCEAN' THEN TEMP_SENSOR = DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS]+'_O' ELSE TEMP_SENSOR = DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS]+'_L'
    ENDIF ELSE TEMP_SENSOR = DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS]
   
    NB_BANDS = SENSOR_BAND_INFO(DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS])
    DB_IDX = STRARR(NB_BANDS)
    TT=0
    FOR I=0,NB_BANDS[0]-1 DO BEGIN
    
      TMP = CONVERT_INDEX_TO_WAVELENGTH(I,TEMP_SENSOR)
      IF TMP NE 'ERROR' THEN BEGIN
        DB_IDX[TT] = STRTRIM(STRING(TT+1),2)+': '+TMP+' nm' 
        TT++
      ENDIF
    ENDFOR
    DB_IDX=DB_IDX[0:TT-1]

;--------------------------
; UPDATE WIDGET FOR USER
        
    DHMI_VISU_INFO.FSCSENS->SETPROPERTY, VALUE=DHMI_VISU_INFO.ASENSS[DHMI_VISU_INFO.ISENS]
    DHMI_VISU_INFO.FSCPROC->SETPROPERTY, VALUE=DHMI_VISU_INFO.APROC[DHMI_VISU_INFO.IPROC]
    WIDGET_CONTROL, DHMI_VISU_INFO.DROPID, SET_VALUE=DB_IDX,SET_UVALUE=DB_IDX

    NO_CHANGE_SENS:
  ENDIF

;--------------------------
; UPDATE PROCESSING VERSION

  IF ACTION_TYPE EQ 'P' THEN BEGIN
  IF DHMI_VISU_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_VISU->CHANGE: CHANGING THE PROCESSING VERSION VALUE'
    CASE ACTION OF
      'PROC<':DHMI_VISU_INFO.IPROC = DHMI_VISU_INFO.IPROC-1
      'PROC>':DHMI_VISU_INFO.IPROC = DHMI_VISU_INFO.IPROC+1
    ENDCASE
    IF DHMI_VISU_INFO.IPROC LT 0 THEN DHMI_VISU_INFO.IPROC = DHMI_VISU_INFO.NAPROC-1
    IF DHMI_VISU_INFO.IPROC EQ DHMI_VISU_INFO.NAPROC THEN DHMI_VISU_INFO.IPROC = 0 
    DHMI_VISU_INFO.FSCPROC->SETPROPERTY, VALUE=DHMI_VISU_INFO.APROC[DHMI_VISU_INFO.IPROC]
  ENDIF

;--------------------------
; RETRUN TO THE WIDGET

  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_VISU_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

pro DHMI_VISU,GROUP_LEADER=GROUP_LEADER,VERBOSE=VERBOSE

WIDGET_CONTROL,/HOURGLASS
COMMON DHMI_DATABASE

;--------------------------
; FIND MAIN DIMITRI FOLDER AND DELIMITER

  IF KEYWORD_SET(VERBOSE) THEN BEGIN
    PRINT,'DHMI_VISU: STARTING HMI VISUALISATION ROUTINE'
    IVERBOSE=1
  ENDIF ELSE IVERBOSE=0

  IF STRUPCASE(!VERSION.OS_FAMILY) EQ 'WINDOWS' THEN WIN_FLAG = 1 ELSE WIN_FLAG = 0  
  CD, CURRENT=CDIR

  DL            = GET_DIMITRI_LOCATION('DL')
  VISU_OFOLDER  = GET_DIMITRI_LOCATION('OUTPUT')
  
;--------------------------
; GET LIST OF ALL OUTPUT FOLDERS
  
  CD,VISU_OFOLDER
  SITE_SEARCH = FILE_SEARCH(/TEST_DIRECTORY)
  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: DIRECTORIES FOUND IN OUTPUT FOLDER = ',SITE_SEARCH
  CD,CDIR
  
  IF SITE_SEARCH[0] EQ '' THEN BEGIN
    MSG='DHMI_VISU: ERROR, NO SITES FOUND IN INPUT FOLDER!'
    TMP = DIALOG_MESSAGE(MSG,/ERROR,/CENTER)
    RETURN
  ENDIF 

;--------------------------
; GET LIST OF ALL OUTPUT FOLDERS, 
; SITES, SENSORS AND PROCESSING VERSIONS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: RETRIEVING UNIQ SITES, SENSORS AND PROC VERSIONS'
	USITES = DHMI_DB_DATA.REGION[UNIQ(DHMI_DB_DATA.REGION,SORT(DHMI_DB_DATA.REGION))]
	USENSS = DHMI_DB_DATA.SENSOR[UNIQ(DHMI_DB_DATA.SENSOR,SORT(DHMI_DB_DATA.SENSOR))]
	UPROCV = DHMI_DB_DATA.PROCESSING_VERSION[UNIQ(DHMI_DB_DATA.PROCESSING_VERSION,$
	                                     SORT(DHMI_DB_DATA.PROCESSING_VERSION))]

	NOUTFS = N_ELEMENTS(SITE_SEARCH)
	NSITES = N_ELEMENTS(USITES)
	NSENSS = N_ELEMENTS(USENSS)
	NPROCV = N_ELEMENTS(UPROCV)

;--------------------------
; CREATE AN ARRAY TO HOLD INFORMATION IF PROC_VERSION 
; IS AVAILABLE FOR EACH SENSOR, SITE AND OUTPUTFOLDER

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: CREATING ARRAY OF AVAILABLE INDEXES'
	DATA_AVBLE = MAKE_ARRAY(NPROCV,NSENSS,NSITES,NOUTFS,/INTEGER,VALUE=1)

;;--------------------------
;; GET A LIST OF ALL FILES
;
;  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: RETRIEVING LIST OF ALL FILES'
;  FILE_LIST = FILE_SEARCH(VISU_OFOLDER,'*',/FULLY_QUALIFY_PATH)

;--------------------------
; LOOP OVER EACH VARIABLE, SEARCH FOR FILES 
; WITH CORRECT TITLES, IF MORE THAN ONE FOUND 
; THEN INSERT A 1 IN DATA_AVBLE

;  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: STARTING LOOP OVER ALL COMBINATIONS TO FIND DATA'
;  FOR H=0,NOUTFS-1 DO BEGIN
;    FOR I=0,NSITES-1 DO BEGIN
;      FOR J=0,NSENSS-1 DO BEGIN
;        FOR K=0,NPROCV-1 DO BEGIN
;          TMP = '*'+SITE_SEARCH[H]+'*'+USITES[I]+'*_'+USENSS[J]+'_'+UPROCV[K]+'_*'
;          RES = STRMATCH(FILE_LIST,TMP) 
;          IF TOTAL(RES) GT 0 THEN DATA_AVBLE[K,J,I,H]=1
;        ENDFOR
;      ENDFOR
;    ENDFOR
;  ENDFOR

;--------------------------
; DEFINE ARRAYS FOR CURRENTLY 
; AVAILABLE CONFIGURATIONS AND INDEXES
  
  VOUTF = SITE_SEARCH[0]
  IOUTF = 0

;--------------------------
; GET AN ARRAY OF AVAILABLE 
; SITES FOR THIS OUTPUTFOLDER

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: CREATING ARRAYS TO HOLD AVAILABLE INFORMATION'
  ASITES = USITES
  ASENSS = USENSS
  APROC = UPROCV
  NASITE=NSITES
  

;--------------------------
; FIND AVAILABLE SITES

;  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: FINDING AVAILABLE SITES WITHIN OUTPUTFOLDER'
;  FOR I=0,NSITES-1 DO BEGIN 
;  RES = TOTAL(DATA_AVBLE[*,*,I,IOUTF])
;    IF RES GT 0 THEN BEGIN
;      ASITES[NASITE]=USITES[I]
;      NASITE++
;    ENDIF
;  ENDFOR

 ; ISITE = WHERE(USITES EQ ASITES[0])
  ISITE = 0
  VSITE = USITES[ISITE]

;--------------------------
; FIND AVAILABLE SENSORS
 
  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: FINDING AVAILABLE SENSORS WITHIN SITE AND OUTPUTFOLDER' 
  NASENS=0
  NASENS=NSENSS 
;  FOR J=0,NSENSS-1 DO BEGIN 
;    RES = TOTAL(DATA_AVBLE[*,J,ISITE,IOUTF])
;    IF RES GT 0 THEN BEGIN
;      ASENSS[NASENS]=USENSS[J]
;      NASENS++
;    ENDIF
;  ENDFOR

;  ISENS = WHERE(USENSS EQ ASENSS[0])
isens=0
  VSENS = USENSS[ISENS]

;--------------------------
; FIND AVAILABLE PROCESSING VERSIONS

  IF KEYWORD_SET(VERBOSE) THEN $
    PRINT,'DHMI_VISU: FINDING AVAILABLE PROC_VERSIONS WITHIN SENSOR, SITE AND OUTPUTFOLDER'
  NAPROC=0
  NAPROC=NPROCV
;  FOR K=0,NPROCV-1 DO BEGIN 
;    IF DATA_AVBLE[K,ISENS,ISITE,IOUTF] GT 0 THEN BEGIN
;      APROC[NAPROC]=UPROCV[K]
;      NAPROC++
;    ENDIF
;  ENDFOR
;
;  IPROC = WHERE(UPROCV EQ APROC[0])
iproc = 0
  VPROC = UPROCV[IPROC]
  IOUTF = 0 & ISITE = 0 & ISENS = 0 & IPROC = 0

;-----------------------------------------
; RETRIEVE THE SITE TYPE

  SITE_TYPE = GET_SITE_TYPE(VSITE) 

;-----------------------------------------
; MODISA SURFACE DEPENDANCE EXCEPTION

  IF VSENS EQ 'MODISA' THEN BEGIN
    IF STRUPCASE(SITE_TYPE) EQ 'OCEAN' THEN TEMP_SENSOR = VSENS+'_O' ELSE TEMP_SENSOR = VSENS+'_L'
  ENDIF ELSE TEMP_SENSOR = VSENS

;--------------------------
; GET A LIST OF ALL DIMITRI BANDS, 
; FIND WHICH BANDS ARE AVAILABLE FOR THIS SENSOR

  IF KEYWORD_SET(VERBOSE) THEN $
    PRINT,'DHMI_VISU: RETRIEVING LIST OF ALL DIMITRI BANDS AVAILABLE FOR SELECTED SENSOR'
  NB_BANDS = SENSOR_BAND_INFO(VSENS)
  DB_IDX = STRARR(NB_BANDS)
  TT=0
  FOR I=0,NB_BANDS[0]-1 DO BEGIN
    TMP = CONVERT_INDEX_TO_WAVELENGTH(I[0],TEMP_SENSOR)
    IF TMP NE 'ERROR' THEN BEGIN
      DB_IDX[TT] = STRTRIM(STRING(TT+1),2)+': '+TMP+' nm' 
      TT++
    ENDIF
  ENDFOR
  DB_IDX=DB_IDX[0:TT-1]

;--------------------------
; DEFINE THE MAIN WIDGET INCLUDING 
; FSC_FIELDS AND DROPLIST

  DIMS  = GET_SCREEN_SIZE()
  XSIZE = 450
  YSIZE = 500
  OPT_BTN = 60
  XLOC  = (DIMS[0]/2)-(XSIZE/2)
  YLOC  = (DIMS[1]/2)-(YSIZE/2)

;--------------------------
; DEFINE MAIN WIDGET

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: CREATING THE WIDGET TO CONTAIN ALL FIELDS AND BUTTONS'
  DHMI_VISU_TLB = WIDGET_BASE(COLUMN=1,TITLE='DIMITRI V2.0: VISU SETUP',XSIZE=XSIZE,XOFFSET=XLOC,YOFFSET=YLOC)
  DHMI_VISU_TLB_PAR     = WIDGET_BASE(DHMI_VISU_TLB,COLUMN=1,FRAME=1,/ALIGN_CENTER)

;--------------------------
; DEFINE WIDGET LABEL

  DHMI_VISU_TLB_PAR_TMP = WIDGET_LABEL(DHMI_VISU_TLB_PAR,VALUE='')
  DHMI_VISU_TLB_PAR_LBL = WIDGET_LABEL(DHMI_VISU_TLB_PAR,VALUE='VISUALISATION PARAMETERS :',/ALIGN_LEFT)
  DHMI_VISU_TLB_PAR_TMP = WIDGET_LABEL(DHMI_VISU_TLB_PAR,VALUE='')

;--------------------------
; DEFINE WIDGET BASE TO HOLD FSC FIELDS

  DHMI_VISU_TLB_PAR_FSC     = WIDGET_BASE(DHMI_VISU_TLB_PAR,ROW=5,XSIZE=XSIZE-15)

;--------------------------
; DEFINE WIDGET FSC FIELDS AND BUTTONS

  IF WIN_FLAG THEN DHMI_VISU_TLB_PAR_FSC_OID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='FOLDER          : ', VALUE=VOUTF,OBJECT=FSCOUTF,/NOEDIT,XSIZE=45) $
    ELSE DHMI_VISU_TLB_PAR_FSC_OID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='FOLDER     : ', VALUE=VOUTF,OBJECT=FSCOUTF,/NOEDIT,XSIZE=45)
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='<',$
                                              UVALUE= 'OUTF<',EVENT_PRO='DHMI_VISU_CHANGE')
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='>',$
                                              UVALUE= 'OUTF>',EVENT_PRO='DHMI_VISU_CHANGE') 

  IF WIN_FLAG THEN DHMI_VISU_TLB_PAR_FSC_RID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='REGION          : ', VALUE=VSITE,OBJECT=FSCSITE,/NOEDIT) $
    ELSE DHMI_VISU_TLB_PAR_FSC_RID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='REGION     : ', VALUE=VSITE,OBJECT=FSCSITE,/NOEDIT)
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='<',$
                                              UVALUE= 'RSITE<',EVENT_PRO='DHMI_VISU_CHANGE')
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='>',$
                                              UVALUE= 'RSITE>',EVENT_PRO='DHMI_VISU_CHANGE') 

  IF WIN_FLAG THEN DHMI_VISU_TLB_PAR_FSC_SID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='REF SENSOR : ', VALUE=VSENS,OBJECT=FSCSENS,/NOEDIT) $
    ELSE DHMI_VISU_TLB_PAR_FSC_SID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='REF SENSOR : ', VALUE=VSENS,OBJECT=FSCSENS,/NOEDIT)
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='<',$
                                              UVALUE= 'SENSOR<',EVENT_PRO='DHMI_VISU_CHANGE')
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='>',$
                                              UVALUE= 'SENSOR>',EVENT_PRO='DHMI_VISU_CHANGE') 

  IF WIN_FLAG THEN DHMI_VISU_TLB_PAR_FSC_PID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='PROC_VER     : ', VALUE=VPROC,OBJECT=FSCPROC,/NOEDIT) $
    ELSE DHMI_VISU_TLB_PAR_FSC_PID  = FSC_FIELD(DHMI_VISU_TLB_PAR_FSC, TITLE='PROC_VER   : ', VALUE=VPROC,OBJECT=FSCPROC,/NOEDIT)
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='<',$
                                              UVALUE= 'PROC<',EVENT_PRO='DHMI_VISU_CHANGE')
  DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_FSC,VALUE='>',$
                                              UVALUE= 'PROC>',EVENT_PRO='DHMI_VISU_CHANGE') 

  IF WIN_FLAG THEN DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_LABEL(DHMI_VISU_TLB_PAR_FSC,VALUE=' REF BAND  : ') $
    ELSE DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_LABEL(DHMI_VISU_TLB_PAR_FSC,VALUE=' REF BAND  : ')
  DHMI_VISU_TLB_PAR_DRPID    = WIDGET_DROPLIST(DHMI_VISU_TLB_PAR_FSC, VALUE=DB_IDX, UVALUE=DB_IDX,$
                                              EVENT_PRO='DHMI_VISU_DROPLIST')
  ;DHMI_VISU_TLB_PAR_FSC_TMP  = WIDGET_LABEL(DHMI_VISU_TLB_PAR_FSC,VALUE='') 

;--------------------------
; DEFINE WIDGET BASE IN MAIN

  DHMI_VISU_TLB_PAR_OPT      = WIDGET_BASE(DHMI_VISU_TLB,ROW=1,/ALIGN_RIGHT)

;--------------------------
; DEFINE TWO BUTTONS FOR START AND CLOSE

  DHMI_VISU_TLB_PAR_OPT_BTN  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_OPT,VALUE='Start',$  
                                              UVALUE='START',EVENT_PRO='DHMI_VISU_START',XSIZE=OPT_BTN)
  DHMI_VISU_TLB_PAR_OPT_BTN  = WIDGET_BUTTON(DHMI_VISU_TLB_PAR_OPT,VALUE='Close',EVENT_PRO='DHMI_VISU_EXIT',XSIZE=OPT_BTN)

;--------------------------
; DEFINE STRUCTURE TO HOLD ALL DATA FOR WIDGET

  IF KEYWORD_SET(VERBOSE) THEN $
    PRINT,'DHMI_VISU: CREATEING STRUCTURE TO HOLD ALL REQUIRED WIDGET INFORMATION'
  IF NOT KEYWORD_SET(GROUP_LEADER) THEN GROUP_LEADER = DHMI_VISU_TLB
  DHMI_VISU_INFO = {                                      $
                  IVERBOSE      : IVERBOSE                ,$
                  GROUP_LEADER  : GROUP_LEADER            ,$
                  VISU_OFOLDER  : VISU_OFOLDER            ,$
                  DL            : DL                      ,$
                  CDIR          : CDIR                    ,$       
                  FSCOUTF       : FSCOUTF                 ,$
                  FSCSITE       : FSCSITE                 ,$
                  FSCSENS       : FSCSENS                 ,$
                  FSCPROC       : FSCPROC                 ,$
                  USITES        : USITES                  ,$
                  USENSS        : USENSS                  ,$
                  UPROCV        : UPROCV                  ,$   
                  NASITE        : NASITE                  ,$
                  NAPROC        : NAPROC                  ,$
                  NASENS        : NASENS                  ,$
                  NOUTFS        : NOUTFS                  ,$
                  NSITES        : NSITES                  ,$
                  NSENSS        : NSENSS                  ,$
                  NPROCV        : NPROCV                  ,$
                  DATA_AVBLE    : DATA_AVBLE              ,$
                  AOUTF         : SITE_SEARCH             ,$
                  VOUTF         : VOUTF                   ,$
                  IOUTF         : IOUTF                   ,$
                  ASITES        : ASITES                  ,$
                  ISITE         : ISITE                   ,$
                  VSITE         : VSITE                   ,$
                  ASENSS        : ASENSS                  ,$
                  ISENS         : ISENS                   ,$
                  VSENS         : VSENS                   ,$
                  APROC         : APROC                   ,$
                  IPROC         : IPROC                   ,$
                  VPROC         : VPROC                   ,$
                  DROPID        : DHMI_VISU_TLB_PAR_DRPID $
                 }

;--------------------------
; REALISE THE WIDGET AND REGISTER WITH THE XMANAGER

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_VISU: REALISING THE WIDGET AND REGISTERING WITH THE XMANAGER'
  WIDGET_CONTROL,DHMI_VISU_TLB,/REALIZE,/NO_COPY,SET_UVALUE=DHMI_VISU_INFO,GROUP_LEADER=GROUP_LEADER
  XMANAGER,'DHMI_VISU', DHMI_VISU_TLB

END
