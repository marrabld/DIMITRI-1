;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      DHMI_PROCESS_4    
;* 
;* PURPOSE:
;*      THIS PROGRAM DISPLAYS A WIDGET ALLOWING SPECIFICATION OF THE REQUIRED PARAMETERS 
;*      TO LAUNCH THE GLINT VICARIOUS CALIBRATION
;*
;* CALLING SEQUENCE:
;*      DHMI_PROCESS_4
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
;*      01 NOV 2013 - C MAZERAN - DIMITRI-2 V1.0
;*
;* VALIDATION HISTORY:
;*      01 NOV 2013 - C MAZERAN - LINUX 64-BIT IDL 8.2 NOMINAL COMPILATION AND OPERATION       
;*
;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_4_START,EVENT

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P4_INFO, /NO_COPY

;---------------------------
; RETRIEVE ALL PARAMETERS

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->START: RETRIEVING PARAMETERS FROM WIDGET FIELDS' 
  DHMI_P4_INFO.FSCP4_REGION->GETPROPERTY,  VALUE=P4_REGION
  DHMI_P4_INFO.FSCP4_SENSOR->GETPROPERTY,  VALUE=P4_SENSOR
  DHMI_P4_INFO.FSCP4_PROC->GETPROPERTY,    VALUE=P4_PROC
  DHMI_P4_INFO.FSCP4_YEAR->GETPROPERTY,    VALUE=P4_YEAR
  DHMI_P4_INFO.FSCP4_OFOLDER->GETPROPERTY, VALUE=P4_OFOLDER
  DHMI_P4_INFO.FSCP4_CSP->GETPROPERTY,     VALUE=P4_CSPERCENT
  DHMI_P4_INFO.FSCP4_RIP->GETPROPERTY,     VALUE=P4_ROIPERCENT
  DHMI_P4_INFO.FSCP4_WINDMAX->GETPROPERTY, VALUE=P4_WINDMAX
  DHMI_P4_INFO.FSCP4_CONEMAX->GETPROPERTY, VALUE=P4_CONEMAX
  P4_BREF = DHMI_P4_INFO.FSCP4_BREF
  DHMI_P4_INFO.FSCP4_WAVREF->GETPROPERTY,  VALUE=P4_WAVREF
  DHMI_P4_INFO.FSCP4_CALREF->GETPROPERTY,  VALUE=P4_CALREF
  DHMI_P4_INFO.FSCP4_CHL->GETPROPERTY,     VALUE=P4_CHL
  DHMI_P4_INFO.FSCP4_TAU865->GETPROPERTY,  VALUE=P4_TAU865
  DHMI_P4_INFO.FSCP4_AER->GETPROPERTY,     VALUE=P4_AER
  IF DHMI_P4_INFO.CURRENT_BUTTON_PIX EQ DHMI_P4_INFO.DHMI_P4_TLB_PIX1 THEN PIX = 1 ELSE PIX = 0
  IF DHMI_P4_INFO.CURRENT_BUTTON_CLIM EQ DHMI_P4_INFO.DHMI_P4_TLB_CLIM1 THEN CLIM = 1 ELSE CLIM = 0  

;---------------------------
; CHECK USER VALUES

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->START: CHECKING USER PARAMETERS'
  ERR_CLIM = 0
  ERR_CHL  = 0
  ERR_AER  = 0
  IF CLIM EQ 1 THEN BEGIN
    MARINE_DIR = GET_DIMITRI_LOCATION('MARINE')
    RES=FILE_INFO(FILEPATH('CHL_CLIM_'+P4_REGION+'.txt', ROOT_DIR=MARINE_DIR))
    IF RES.EXISTS NE 1 THEN ERR_CLIM=1
  ENDIF ELSE BEGIN
    IF (P4_CHL LT 0.01 OR P4_CHL GT 30) THEN ERR_CHL=1
  ENDELSE
  IF P4_AER EQ '(NONE)' THEN ERR_AER=1
  IF ERR_CLIM OR ERR_CHL OR ERR_AER THEN BEGIN
    MSG = ['INPUT ERROR']
    IF ERR_CLIM THEN MSG = [MSG, 'NO CHL CLIMATOLOGY FILE IN AUXILIARY DATA']
    IF ERR_CHL  THEN MSG = [MSG, 'CHL MUST BE WITHIN [0.01,30]']
    IF ERR_AER  THEN MSG = [MSG, 'NO AEROSOL AVAILABLE IN AUX_DATA FOR CHOSEN SENSOR']
    TEMP = DIALOG_MESSAGE(MSG,/INFORMATION,/CENTER)
    GOTO, P4_ERR
  ENDIF

;---------------------------
; SORT OUT OUTPUT FOLDER NAME
 
  IF P4_OFOLDER EQ 'AUTO' THEN BEGIN
  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->START: CREATING OUTPUTFOLDER NAME'
    DATE        = SYSTIME(/UTC)
    MNTHS       = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
    RES         = WHERE(MNTHS EQ STRUPCASE(STRMID(DATE,4,3)))+1
    IF RES LE 9 THEN RES = '0'+STRTRIM(STRING(RES),2) ELSE RES = STRTRIM(STRING(RES),2)
    DD = FIX(STRMID(DATE,8,2)) LE 9 ?  '0'+STRMID(DATE,9,1):STRMID(DATE,8,2)
    DATE        = STRMID(DATE,20,4)+RES+DD
    P4_OFOLDER  = DHMI_P4_INFO.MAIN_OUTPUT+P4_REGION+'_'+DATE+'_GLINT_'+P4_SENSOR+'_'+P4_PROC+'_'+P4_AER
    IF(PIX) THEN P4_OFOLDER +='_PIX'
  ENDIF ELSE P4_OFOLDER = DHMI_P4_INFO.MAIN_OUTPUT+STRJOIN(STRSPLIT(P4_OFOLDER,' ',/EXTRACT),'_')

;---------------------------
; CHECK OUTPUT FOLDER 

  IF FILE_TEST(P4_OFOLDER,/DIRECTORY) EQ 1 THEN BEGIN
    MSG = ['OUTPUT FOLDER ALREADY EXISTS','OVERWRITE DATA?']
    MSG = DIALOG_MESSAGE(MSG,/QUESTION,/CENTER)
    IF STRCMP(STRUPCASE(MSG),'NO') EQ 1 THEN BEGIN
      P4_OFOLDER  = P4_OFOLDER+'_1'
      I = 2
      SCHECK = 0
      WHILE SCHECK EQ 0 DO BEGIN
        
        P4_OFOLDER = STRSPLIT(P4_OFOLDER,'_',/EXTRACT)
        P4_OFOLDER[N_ELEMENTS(P4_OFOLDER)-1] = STRTRIM(STRING(I),2)
        P4_OFOLDER = STRJOIN(P4_OFOLDER,'_')
        
        IF FILE_TEST(P4_OFOLDER,/DIRECTORY) EQ 0 THEN SCHECK = 1
        I++
      ENDWHILE
    ENDIF
  ENDIF

;--------------------------
; GET SCREEN DIMENSIONS FOR 
; CENTERING INFO WIDGET

  DIMS  = GET_SCREEN_SIZE()
  XSIZE = 200
  YSIZE = 60
  XLOC  = (DIMS[0]/2)-(XSIZE/2)
  YLOC  = (DIMS[1]/2)-(YSIZE/2)

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->START: CREATING AN INFO WIDGET'
  INFO_WD = WIDGET_BASE(COLUMN=1, XSIZE=XSIZE, YSIZE=YSIZE, TITLE='Please Wait...',XOFFSET=XLOC,YOFFSET=YLOC)
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE=' ')
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE='Please wait,')
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE='Processing...')
  WIDGET_CONTROL, INFO_WD, /REALIZE
  WIDGET_CONTROL, /HOURGLASS

;--------------------------
; GLINT CAL

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->START: RUNNING GLINT CALIBRATION'  
  RES = GLINT_CALIBRATION(P4_OFOLDER,P4_REGION,P4_SENSOR,P4_PROC,P4_YEAR,P4_CSPERCENT,P4_ROIPERCENT,$
                          P4_WINDMAX,P4_CONEMAX,P4_BREF,P4_CALREF,P4_CHL,P4_TAU865,P4_AER, PIX=PIX, CLIM=CLIM, VERBOSE=DHMI_P4_INFO.IVERBOSE)
  
  IF RES NE 1 THEN BEGIN
   MSG = ['DIMITRI PROCESS 4:','ERROR DURING GLINT CAL']
   TMP = DIALOG_MESSAGE(MSG,/INFORMATION,/CENTER)
   GOTO,P4_ERR
  ENDIF

;--------------------------
; DESTROY INFO WIDGET AND RETURN 
; TO PROCESS_4 WIDGET

  P4_ERR:
  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->START: DESTROYING INFO WIDGET AND RETURNING'
  IF N_ELEMENTS(INFO_WD) GT 0 THEN WIDGET_CONTROL,INFO_WD,/DESTROY
  NO_SELECTION:
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P4_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_4_EXIT,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P4_INFO, /NO_COPY
  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->EXIT: DESTROYING OBJECTS'

;--------------------------
; DESTROY OBJECTS

  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_OFOLDER
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_REGION
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_SENSOR
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_PROC
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_YEAR
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_CSP
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_RIP
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_WINDMAX
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_CONEMAX
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_WAVREF
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_CALREF
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_CHL
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_TAU865
  OBJ_DESTROY,DHMI_P4_INFO.FSCP4_AER

;--------------------------
; DESTROY THE WIDGET

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->EXIT: DESTROYING PROCESS 4 WIDGET'
  WIDGET_CONTROL,EVENT.TOP,/DESTROY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_4_PIX,EVENT

COMMON DHMI_DATABASE

;--------------------------
; GET EVENT AND WIDGET INFO

  WIDGET_CONTROL, EVENT.TOP, GET_UVALUE=DHMI_P4_INFO, /NO_COPY

;---------------------
; UPDATE CURRENT_BUTTON WITH SELECTION

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->PIX: UPDATING CURRENT BUTTON SELECTION'
  DHMI_P4_INFO.CURRENT_BUTTON_PIX = EVENT.ID
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P4_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_4_CLIM,EVENT

COMMON DHMI_DATABASE

;--------------------------
; GET EVENT AND WIDGET INFO

  WIDGET_CONTROL, EVENT.TOP, GET_UVALUE=DHMI_P4_INFO, /NO_COPY

;---------------------
; UPDATE CURRENT_BUTTON_CLIM WITH SELECTION

  IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4->CLIM: UPDATING CURRENT BUTTON SELECTION'
  DHMI_P4_INFO.CURRENT_BUTTON_CLIM = EVENT.ID
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P4_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_4_SETUP_CHANGE,EVENT

COMMON DHMI_DATABASE
  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P4_INFO, /NO_COPY
  WIDGET_CONTROL, EVENT.ID,   GET_UVALUE=ACTION

;--------------------------
; GET THE ACTION TYPE

  ACTION_TYPE = STRMID(ACTION,0,1)

;--------------------------
; UPDATE SENSOR VALUE

  IF ACTION_TYPE EQ 'V' THEN BEGIN
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4_SETUP->CHANGE: UPDATING THE SITE FIELD AND INDEX'
    CASE ACTION OF
      'VSITE<':DHMI_P4_INFO.ISITE = DHMI_P4_INFO.ISITE-1
      'VSITE>':DHMI_P4_INFO.ISITE = DHMI_P4_INFO.ISITE+1
    ENDCASE
    IF DHMI_P4_INFO.ISITE LT 0 THEN DHMI_P4_INFO.ISITE = DHMI_P4_INFO.NASITE-1
    IF DHMI_P4_INFO.ISITE EQ DHMI_P4_INFO.NASITE THEN DHMI_P4_INFO.ISITE = 0

    DHMI_P4_INFO.FSCP4_REGION->SETPROPERTY, VALUE=DHMI_P4_INFO.ASITE[DHMI_P4_INFO.ISITE]

;--------------------------
; GET AVAILABLE SENSORS WITHIN REGION

    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_4_SETUP->CHANGE: UPDATING THE SENSOR FIELD AND INDEX'
    CSITE=DHMI_P4_INFO.ASITE[DHMI_P4_INFO.ISITE]

    TEMP = DHMI_DB_DATA.SENSOR[WHERE(STRMATCH(DHMI_DB_DATA.REGION,CSITE))]
    TEMP = TEMP[UNIQ(TEMP,SORT(TEMP))]
    DHMI_P4_INFO.ASENS[0:N_ELEMENTS(TEMP)-1] = TEMP
    DHMI_P4_INFO.NASENS = N_ELEMENTS(TEMP)
    DHMI_P4_INFO.ISENS  = 0
    DHMI_P4_INFO.FSCP4_SENSOR->SETPROPERTY, VALUE=DHMI_P4_INFO.ASENS[DHMI_P4_INFO.ISENS]

    GOTO,UPDATE_PROC

  ENDIF

;--------------------------
; UPDATE SENSOR VALUE

  IF ACTION_TYPE EQ 'S' THEN BEGIN
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE SENSOR FIELD AND INDEX'
    CASE ACTION OF
      'SENS<':DHMI_P4_INFO.ISENS = DHMI_P4_INFO.ISENS-1
      'SENS>':DHMI_P4_INFO.ISENS = DHMI_P4_INFO.ISENS+1
    ENDCASE
    IF DHMI_P4_INFO.ISENS LT 0 THEN DHMI_P4_INFO.ISENS = DHMI_P4_INFO.NASENS-1
    IF DHMI_P4_INFO.ISENS EQ DHMI_P4_INFO.NASENS THEN DHMI_P4_INFO.ISENS = 0

    DHMI_P4_INFO.FSCP4_SENSOR->SETPROPERTY, VALUE=DHMI_P4_INFO.ASENS[DHMI_P4_INFO.ISENS]

;--------------------------
; GET AVAILABLE PROC_VERS 
; FOR SITE AND SENSOR

    UPDATE_PROC:
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE PROCESSING VERSION FIELD AND INDEX'
    CSITE = DHMI_P4_INFO.ASITE[DHMI_P4_INFO.ISITE]
    CSENS = DHMI_P4_INFO.ASENS[DHMI_P4_INFO.ISENS]

    TEMP = DHMI_DB_DATA.PROCESSING_VERSION[WHERE($
                                                 STRMATCH(DHMI_DB_DATA.REGION,CSITE) AND $
                                                 STRMATCH(DHMI_DB_DATA.SENSOR,CSENS))]
    TEMP = TEMP[UNIQ(TEMP,SORT(TEMP))]
    DHMI_P4_INFO.APROC[0:N_ELEMENTS(TEMP)-1] = TEMP
    DHMI_P4_INFO.NAPROC = N_ELEMENTS(TEMP)
    DHMI_P4_INFO.IPROC  = 0
    DHMI_P4_INFO.FSCP4_PROC->SETPROPERTY, VALUE=DHMI_P4_INFO.APROC[DHMI_P4_INFO.IPROC]

;--------------------------
; GET AVAILABLE AER 
; FOR SENSOR

    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE AEROSOL FIELD AND INDEX'
    CSENS = DHMI_P4_INFO.ASENS[DHMI_P4_INFO.ISENS]

    RTM_DIR = GET_DIMITRI_LOCATION('RTM',VERBOSE=DHMI_P4_INFO.IVERBOSE)
    SEARCH_DIR = FILEPATH(CSENS,ROOT_DIR=RTM_DIR)
    PATTERN='XC_'+CSENS+'_'
    SEARCH_FILTER = PATTERN+'*.txt'
    RES=FILE_SEARCH(SEARCH_DIR,SEARCH_FILTER,COUNT=NAER,/TEST_REGULAR)
    IF NAER EQ 0 THEN BEGIN
      NAER=1
      DHMI_P4_INFO.AAER[0] = '(NONE)'
    ENDIF ELSE BEGIN
      POS=STRPOS(RES,PATTERN,/REVERSE_SEARCH)
      PS =STRLEN(PATTERN)
      FOR IAER=0, NAER-1 DO DHMI_P4_INFO.AAER[IAER]=STRMID(RES[IAER],POS[IAER]+PS,STRLEN(RES[IAER])-POS[IAER]-PS-4)
    ENDELSE
    DHMI_P4_INFO.NAER = NAER
    DHMI_P4_INFO.IAER  = 0
    DHMI_P4_INFO.FSCP4_AER->SETPROPERTY, VALUE=DHMI_P4_INFO.AAER[DHMI_P4_INFO.IAER]

;--------------------------
; GET AVAILABLE BREF AND WAVREF
; FOR SENSOR (<= 865 NM)

    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE BREF FIELD AND INDEX'
    CSENS = DHMI_P4_INFO.ASENS[DHMI_P4_INFO.ISENS]

    IF CSENS EQ 'MODISA' THEN TEMP_SENS = 'MODISA_O' ELSE TEMP_SENS = CSENS
    IBREF=0
    NBREF=0
    FOR BB = 1, DHMI_P4_INFO.BBREF_MAX DO BEGIN
       BREF = GET_SENSOR_BAND_INDEX(TEMP_SENS,BB)
       IF BREF LT 0 THEN CONTINUE ELSE BEGIN
         DHMI_P4_INFO.ABREF[NBREF]    = BREF
         DHMI_P4_INFO.AWAVREF[NBREF]  = GET_SENSOR_BAND_NAME(CSENS,BREF)
         IF BB EQ DHMI_P4_INFO.BASE_BBREF THEN IBREF=NBREF
         NBREF++
       ENDELSE
    ENDFOR
    DHMI_P4_INFO.NBREF = NBREF 
    DHMI_P4_INFO.IBREF = IBREF
    DHMI_P4_INFO.FSCP4_BREF=DHMI_P4_INFO.ABREF[DHMI_P4_INFO.IBREF]
    DHMI_P4_INFO.FSCP4_WAVREF->SETPROPERTY, VALUE=DHMI_P4_INFO.AWAVREF[DHMI_P4_INFO.IBREF]

    GOTO,UPDATE_YEAR

  ENDIF

;--------------------------
; UPDATE PROC VALUE

  IF ACTION_TYPE EQ 'P' THEN BEGIN
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE PROCESSING VERSION FIELD AND INDEX'
    CASE ACTION OF
      'PROC<':DHMI_P4_INFO.IPROC = DHMI_P4_INFO.IPROC-1
      'PROC>':DHMI_P4_INFO.IPROC = DHMI_P4_INFO.IPROC+1
    ENDCASE
    IF DHMI_P4_INFO.IPROC LT 0 THEN DHMI_P4_INFO.IPROC = DHMI_P4_INFO.NAPROC-1
    IF DHMI_P4_INFO.IPROC EQ DHMI_P4_INFO.NAPROC THEN DHMI_P4_INFO.IPROC = 0

    DHMI_P4_INFO.FSCP4_PROC->SETPROPERTY, VALUE=DHMI_P4_INFO.APROC[DHMI_P4_INFO.IPROC]

;--------------------------
; GET AVAILABLE YEARS FOR SITE,
; SENSOR AND PROC VERSION

    UPDATE_YEAR:
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE YEAR FIELD AND INDEX'
    CSITE = DHMI_P4_INFO.ASITE[DHMI_P4_INFO.ISITE]
    CSENS = DHMI_P4_INFO.ASENS[DHMI_P4_INFO.ISENS]
    CPROC = DHMI_P4_INFO.APROC[DHMI_P4_INFO.IPROC]

    TEMP = STRTRIM(STRING(DHMI_DB_DATA.YEAR[WHERE($
                                                  STRMATCH(DHMI_DB_DATA.REGION,CSITE)       AND $
                                                  STRMATCH(DHMI_DB_DATA.SENSOR,CSENS)       AND $
                                                  STRMATCH(DHMI_DB_DATA.PROCESSING_VERSION,CPROC))]),2)
    TEMP = TEMP[UNIQ(TEMP,SORT(TEMP))]
    DHMI_P4_INFO.AYEAR[0:N_ELEMENTS(TEMP)] = [TEMP,'ALL']
    DHMI_P4_INFO.NAYEAR = N_ELEMENTS(TEMP)+1
    DHMI_P4_INFO.IYEAR=0
    DHMI_P4_INFO.FSCP4_YEAR->SETPROPERTY, VALUE=DHMI_P4_INFO.AYEAR[DHMI_P4_INFO.IYEAR]

  ENDIF

;--------------------------
; UPDATE YEAR VALUE

  IF ACTION_TYPE EQ 'Y' THEN BEGIN
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE YEAR FIELD AND INDEX'
    CASE ACTION OF
      'YEAR<':DHMI_P4_INFO.IYEAR = DHMI_P4_INFO.IYEAR-1
      'YEAR>':DHMI_P4_INFO.IYEAR = DHMI_P4_INFO.IYEAR+1
    ENDCASE
    IF DHMI_P4_INFO.IYEAR LT 0 THEN DHMI_P4_INFO.IYEAR = DHMI_P4_INFO.NAYEAR-1
    IF DHMI_P4_INFO.IYEAR EQ DHMI_P4_INFO.NAYEAR THEN DHMI_P4_INFO.IYEAR = 0

    DHMI_P4_INFO.FSCP4_YEAR->SETPROPERTY, VALUE=DHMI_P4_INFO.AYEAR[DHMI_P4_INFO.IYEAR]
  ENDIF

;--------------------------
; UPDATE AER VALUE

  IF ACTION_TYPE EQ 'A' THEN BEGIN
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING THE AEROSOL FIELD AND INDEX'
    CASE ACTION OF
      'AER<':DHMI_P4_INFO.IAER = DHMI_P4_INFO.IAER-1
      'AER>':DHMI_P4_INFO.IAER = DHMI_P4_INFO.IAER+1
    ENDCASE
    IF DHMI_P4_INFO.IAER LT 0 THEN DHMI_P4_INFO.IAER = DHMI_P4_INFO.NAER-1
    IF DHMI_P4_INFO.IAER EQ DHMI_P4_INFO.NAER THEN DHMI_P4_INFO.IAER = 0

    DHMI_P4_INFO.FSCP4_AER->SETPROPERTY, VALUE=DHMI_P4_INFO.AAER[DHMI_P4_INFO.IAER]
  ENDIF

;--------------------------
; UPDATE BREF AND WAVREF VALUE

  IF ACTION_TYPE EQ 'B' THEN BEGIN
    IF DHMI_P4_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESSOR_4_SETUP->CHANGE: UPDATING BREF FIELD AND INDEX'
    CASE ACTION OF
      'BREF<':DHMI_P4_INFO.IBREF = DHMI_P4_INFO.IBREF-1
      'BREF>':DHMI_P4_INFO.IBREF = DHMI_P4_INFO.IBREF+1
    ENDCASE
    IF DHMI_P4_INFO.IBREF LT 0 THEN DHMI_P4_INFO.IBREF = DHMI_P4_INFO.NBREF-1
    IF DHMI_P4_INFO.IBREF EQ DHMI_P4_INFO.NBREF THEN DHMI_P4_INFO.IBREF = 0

    DHMI_P4_INFO.FSCP4_BREF=DHMI_P4_INFO.ABREF[DHMI_P4_INFO.IBREF]
    DHMI_P4_INFO.FSCP4_WAVREF->SETPROPERTY, VALUE=DHMI_P4_INFO.AWAVREF[DHMI_P4_INFO.IBREF]
  ENDIF

 
;--------------------------
; RETRUN TO THE WIDGET

  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P4_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_4,GROUP_LEADER=GROUP_LEADER,VERBOSE=VERBOSE

COMMON DHMI_DATABASE

;--------------------------
; FIND MAIN DIMITRI FOLDER AND DELIMITER

  IF KEYWORD_SET(VERBOSE) THEN BEGIN
    PRINT,'DHMI_PROCESS_4: STARTING PROCESS 4 HMI ROUTINE'
    IVERBOSE=1
  ENDIF ELSE IVERBOSE=0
  IF STRUPCASE(!VERSION.OS_FAMILY) EQ 'WINDOWS' THEN WIN_FLAG = 1 ELSE WIN_FLAG = 0
 
  DL          = GET_DIMITRI_LOCATION('DL')
  MAIN_OUTPUT = GET_DIMITRI_LOCATION('OUTPUT')

;--------------------------
; DEFINE BASE PARAMETERS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: DEFINING BASE PARAMETERS'
  CFIG_DATA = GET_DIMITRI_CONFIGURATION() 

  BASE_CLOUD  = CFIG_DATA.(1)[7]
  BASE_ROI    = CFIG_DATA.(1)[8] 
  NAER_MAX    = FIX(CFIG_DATA.(1)[14])
  BASE_WIND   = CFIG_DATA.(1)[15]
  BASE_CHL    = CFIG_DATA.(1)[16]
  BASE_CONE   = CFIG_DATA.(1)[18]
  BASE_BBREF  = FIX(CFIG_DATA.(1)[19])
  BBREF_MAX   = FIX(CFIG_DATA.(1)[20])   
  BASE_CALREF = CFIG_DATA.(1)[21]
  BASE_TAU865 = CFIG_DATA.(1)[22]

  OPT_BTN   = 60
  SML_BTNX  = 30
  SML_BTNY  = 10 
  SML_DEC   = 2
  SML_FSC_X = 7

;--------------------------
; GET LIST OF ALL OUTPUT FOLDERS, 
; SITES, SENSORS AND PROCESSING VERSIONS

  ASITES = DHMI_DB_DATA.REGION[UNIQ(DHMI_DB_DATA.REGION,SORT(DHMI_DB_DATA.REGION))]
  USENSS = DHMI_DB_DATA.SENSOR[UNIQ(DHMI_DB_DATA.SENSOR,SORT(DHMI_DB_DATA.SENSOR))]
  UPROCV = DHMI_DB_DATA.PROCESSING_VERSION[UNIQ(DHMI_DB_DATA.PROCESSING_VERSION,$
                                       SORT(DHMI_DB_DATA.PROCESSING_VERSION))]
  UYEARS = DHMI_DB_DATA.YEAR[UNIQ(DHMI_DB_DATA.YEAR,SORT(DHMI_DB_DATA.YEAR))]

;--------------------------  
; SELECT FIRST SITE AND GET 
; AVAILABLE SENSORS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: RETRIEVING AVAILABLE SITES AND SENSORS'
  ASENS = MAKE_ARRAY(N_ELEMENTS(USENSS),/STRING,VALUE='')
  APROC = MAKE_ARRAY(N_ELEMENTS(UPROCV),/STRING,VALUE='')
  AYEAR = MAKE_ARRAY(N_ELEMENTS(UYEARS)+1,/STRING,VALUE='')

  NASITE = N_ELEMENTS(ASITES)
  CSITE  = ASITES[0]
  TEMP   = DHMI_DB_DATA.SENSOR[WHERE(DHMI_DB_DATA.REGION EQ CSITE)]
  TEMP   = TEMP[UNIQ(TEMP,SORT(TEMP))]
  ASENS[0:N_ELEMENTS(TEMP)-1] = TEMP
  NASENS = N_ELEMENTS(TEMP)
  CSENS  = ASENS[0]

;--------------------------  
; GET AVAILABLE PROCESSING VERSIONS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: RETRIEVING AVAILABLE PROCESSING VERSIONS'
  TEMP    = DHMI_DB_DATA.PROCESSING_VERSION[WHERE(DHMI_DB_DATA.REGION EQ CSITE AND $
                                                  DHMI_DB_DATA.SENSOR EQ CSENS)]
  TEMP    = TEMP[UNIQ(TEMP,SORT(TEMP))]
  APROC[0:N_ELEMENTS(TEMP)-1] = TEMP
  NAPROC  = N_ELEMENTS(TEMP)
  CPROC   = APROC[0]

;--------------------------  
; GET AVAILABLE YEARS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: RETRIEVING AVAILABLE YEARS'
  TEMP    = STRTRIM(STRING(DHMI_DB_DATA.YEAR[WHERE(DHMI_DB_DATA.REGION EQ CSITE AND $
                                              DHMI_DB_DATA.SENSOR EQ CSENS AND $
                                              DHMI_DB_DATA.PROCESSING_VERSION EQ CPROC)]),2)
  TEMP    = TEMP[UNIQ(TEMP,SORT(TEMP))]
  AYEAR[0:N_ELEMENTS(TEMP)] = [TEMP,'ALL']
  CYEAR   = AYEAR[0]
  NAYEAR  = N_ELEMENTS(TEMP)+1

;--------------------------  
; GET AVAILABLE AER

  AAER=STRARR(NAER_MAX)
  RTM_DIR = GET_DIMITRI_LOCATION('RTM',VERBOSE=VERBOSE)
  SEARCH_DIR = FILEPATH(CSENS,ROOT_DIR=RTM_DIR)
  PATTERN='XC_'+CSENS+'_'
  SEARCH_FILTER = PATTERN+'*.txt'
  RES=FILE_SEARCH(SEARCH_DIR,SEARCH_FILTER,COUNT=NAER,/TEST_REGULAR)
  IF NAER EQ 0 THEN BEGIN
     NAER=1
     AAER[0]='(NONE)'
  ENDIF ELSE BEGIN
    POS=STRPOS(RES,PATTERN,/REVERSE_SEARCH)
    PS =STRLEN(PATTERN)
    FOR IAER=0, NAER-1 DO AAER[IAER]=[STRMID(RES[IAER],POS[IAER]+PS,STRLEN(RES[IAER])-POS[IAER]-PS-4)]
  ENDELSE
  CAER = AAER[0]

;--------------------------  
; GET AVAILABLE BREF

  ABREF=INTARR(BBREF_MAX)
  AWAVREF=STRARR(BBREF_MAX)
  IF CSENS EQ 'MODISA' THEN TEMP_SENS = 'MODISA_O' ELSE TEMP_SENS = CSENS
  
  NBREF=0
  FOR BB = 1, BBREF_MAX DO BEGIN
     BREF = GET_SENSOR_BAND_INDEX(TEMP_SENS,BB)
     IF BREF LT 0 THEN CONTINUE ELSE BEGIN
       ABREF[NBREF]    = BREF
       AWAVREF[NBREF]  = GET_SENSOR_BAND_NAME(CSENS,BREF)
       IF BB EQ BASE_BBREF THEN BEGIN
         CWAVREF = AWAVREF[NBREF]
         FSCP4_BREF = BREF
       ENDIF
       NBREF++
     ENDELSE
  ENDFOR
  NBREF = NBREF

;--------------------------
; DEFINE THE MAIN WIDGET 

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: RETRIEVING SCREEN DIMENSIONS FOR WIDGET'
  DIMS  = GET_SCREEN_SIZE()
  IF WIN_FLAG THEN XSIZE = 425 ELSE XSIZE = 490
  YSIZE = 800
  XLOC  = (DIMS[0]/2)-(XSIZE/2)
  YLOC  = (DIMS[1]/2)-(YSIZE/2)

  DHMI_P4_TLB = WIDGET_BASE(COLUMN=1,TITLE='DIMITRI V2.0: GLINT CAL SETUP',XSIZE=XSIZE,$
                                  XOFFSET=XLOC,YOFFSET=YLOC)
;--------------------------
; DEFINE WIDGET TO HOLD OUTPUTFOLDER,
; REGION, SENSOR AND CONFIGURATION

  DHMI_P4_TLB_1 = WIDGET_BASE(DHMI_P4_TLB,ROW=6, FRAME=1)
  DHMI_P4_TLB_1_LBL = WIDGET_LABEL(DHMI_P4_TLB_1,VALUE='CASE STUDY:')
  DHMI_P4_TLB_1_LBL = WIDGET_LABEL(DHMI_P4_TLB_1,VALUE='')
  DHMI_P4_TLB_1_LBL = WIDGET_LABEL(DHMI_P4_TLB_1,VALUE='')

  IF WIN_FLAG THEN DHMI_P4_TLB_1_OFID = FSC_FIELD(DHMI_P4_TLB_1,VALUE='AUTO',TITLE='FOLDER    :',OBJECT=FSCP4_OFOLDER) $
              ELSE DHMI_P4_TLB_1_OFID = FSC_FIELD(DHMI_P4_TLB_1,VALUE='AUTO',TITLE='FOLDER    :',OBJECT=FSCP4_OFOLDER) 
  DHMI_BLK      = WIDGET_LABEL(DHMI_P4_TLB_1,VALUE='')
  DHMI_BLK      = WIDGET_LABEL(DHMI_P4_TLB_1,VALUE='')

  IF WIN_FLAG THEN DHMI_P4_TLB_1_RID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CSITE,TITLE  ='REGION    :',OBJECT=FSCP4_REGION) $
              ELSE DHMI_P4_TLB_1_RID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CSITE,TITLE  ='REGION    :',OBJECT=FSCP4_REGION)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='<',UVALUE='VSITE<',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='>',UVALUE='VSITE>',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')  
  
  IF WIN_FLAG THEN DHMI_P4_TLB_1_SID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CSENS,TITLE  ='SENSOR    :',OBJECT=FSCP4_SENSOR) $
              ELSE DHMI_P4_TLB_1_SID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CSENS,TITLE  ='SENSOR    :',OBJECT=FSCP4_SENSOR)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='<',UVALUE='SENS<',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='>',UVALUE='SENS>',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')  

  IF WIN_FLAG THEN DHMI_P4_TLB_1_PID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CPROC,TITLE  ='PROCESSING:',OBJECT=FSCP4_PROC) $
              ELSE DHMI_P4_TLB_1_PID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CPROC,TITLE  ='PROCESSING:',OBJECT=FSCP4_PROC)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='<',UVALUE='PROC<',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='>',UVALUE='PROC>',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')  

  IF WIN_FLAG THEN DHMI_P4_TLB_1_YID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CYEAR,TITLE  ='YEAR      :',OBJECT=FSCP4_YEAR) $
              ELSE DHMI_P4_TLB_1_YID = FSC_FIELD(DHMI_P4_TLB_1,VALUE=CYEAR,TITLE  ='YEAR      :',OBJECT=FSCP4_YEAR)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='<',UVALUE='YEAR<',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_1,VALUE='>',UVALUE='YEAR>',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')  

       
;--------------------------
; DEFINE WIDGET TO HOLD  
; CLOUD AND ROI PARAMETERS

  DHMI_P4_TLB_2       = WIDGET_BASE(DHMI_P4_TLB,ROW=2,FRAME=1)
  DHMI_P4_TLB_2_LBL   = WIDGET_LABEL(DHMI_P4_TLB_2,VALUE='COVERAGE CRITERIA:')
  DHMI_P4_TLB_2_LBL   = WIDGET_LABEL(DHMI_P4_TLB_2,VALUE='')
  IF WIN_FLAG THEN DHMI_P4_TLB_2_CSPID = FSC_FIELD(DHMI_P4_TLB_2,VALUE=BASE_CLOUD,TITLE='CLOUD %   :',OBJECT=FSCP4_CSP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X) $
              ELSE DHMI_P4_TLB_2_CSPID = FSC_FIELD(DHMI_P4_TLB_2,VALUE=BASE_CLOUD,TITLE='CLOUD %   :',OBJECT=FSCP4_CSP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X)
  IF WIN_FLAG THEN DHMI_P4_TLB_2_RIPID = FSC_FIELD(DHMI_P4_TLB_2,VALUE=BASE_ROI,TITLE ='REGION %   :',OBJECT=FSCP4_RIP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X) $  
              ELSE DHMI_P4_TLB_2_RIPID = FSC_FIELD(DHMI_P4_TLB_2,VALUE=BASE_ROI,TITLE ='REGION %   :',OBJECT=FSCP4_RIP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X)

;--------------------------
; DEFINE WIDGET TO HOLD  
; GLINT CAL PARAMETERS

  DHMI_P4_TLB_3       = WIDGET_BASE(DHMI_P4_TLB,COLUMN=1,FRAME=1)
  DHMI_P4_TLB_3_LBL   = WIDGET_LABEL(DHMI_P4_TLB_3,VALUE='GLINT CAL PARAMETERS:', /ALIGN_LEFT)

  DHMI_P4_TLB_PID     = WIDGET_BASE(DHMI_P4_TLB_3,ROW=1)
  DHMI_P4_TLB_LBL     = WIDGET_LABEL(DHMI_P4_TLB_PID,VALUE='PIXEL-BY-PIXEL MODE:')
  DHMI_P4_TLB_PIX     = WIDGET_BASE(DHMI_P4_TLB_PID,ROW=1,/EXCLUSIVE)
  DHMI_P4_TLB_PIX1    = WIDGET_BUTTON(DHMI_P4_TLB_PIX,VALUE='ON',EVENT_PRO='DHMI_PROCESS_4_PIX')
  DHMI_P4_TLB_PIX2    = WIDGET_BUTTON(DHMI_P4_TLB_PIX,VALUE='OFF',EVENT_PRO='DHMI_PROCESS_4_PIX')
  WIDGET_CONTROL, DHMI_P4_TLB_PIX1, SET_BUTTON=1
  CURRENT_BUTTON_PIX = DHMI_P4_TLB_PIX1

  DHMI_P4_TLB_CID     = WIDGET_BASE(DHMI_P4_TLB_3,ROW=1, /BASE_ALIGN_CENTER)
  DHMI_P4_TLB_LBL     = WIDGET_LABEL(DHMI_P4_TLB_CID,VALUE='CHLOROPHYLL CONC.  :')
  DHMI_P4_TLB_CLIM    = WIDGET_BASE(DHMI_P4_TLB_CID,ROW=1,/EXCLUSIVE)
  DHMI_P4_TLB_CLIM1   = WIDGET_BUTTON(DHMI_P4_TLB_CLIM,VALUE='CLIMATOLOGY',EVENT_PRO='DHMI_PROCESS_3_CLIM')
  DHMI_P4_TLB_CLIM2   = WIDGET_BUTTON(DHMI_P4_TLB_CLIM,VALUE='FIXED (MG/M3) :',EVENT_PRO='DHMI_PROCESS_3_CLIM')
  IF WIN_FLAG THEN DHMI_P4_TLB_3_CHID = FSC_FIELD(DHMI_P4_TLB_CID,VALUE=BASE_CHL,   TITLE ='',OBJECT=FSCP4_CHL,DECIMAL=3,XSIZE=SML_FSC_X) $
              ELSE DHMI_P4_TLB_3_CHID = FSC_FIELD(DHMI_P4_TLB_CID,VALUE=BASE_CHL,   TITLE ='',OBJECT=FSCP4_CHL,DECIMAL=3,XSIZE=SML_FSC_X)
  WIDGET_CONTROL, DHMI_P4_TLB_CLIM2, SET_BUTTON=1
  CURRENT_BUTTON_CLIM = DHMI_P4_TLB_CLIM2

  IF WIN_FLAG THEN DHMI_P4_TLB_3_WMID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_WIND,TITLE  ='MAX WIND SPEED (M/S)              :',OBJECT=FSCP4_WINDMAX,DECIMAL=SML_DEC,XSIZE=SML_FSC_X) $  
              ELSE DHMI_P4_TLB_3_WMID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_WIND,TITLE  ='MAX WIND SPEED (M/S)              :',OBJECT=FSCP4_WINDMAX,DECIMAL=SML_DEC,XSIZE=SML_FSC_X)
  IF WIN_FLAG THEN DHMI_P4_TLB_3_CMID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_CONE,TITLE  ='MAX <VIEW,SPECULAR> ANGLE (DEGREE):',OBJECT=FSCP4_CONEMAX,DECIMAL=SML_DEC,XSIZE=SML_FSC_X) $  
              ELSE DHMI_P4_TLB_3_CMID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_CONE,TITLE  ='MAX <VIEW,SPECULAR> ANGLE (DEGREE):',OBJECT=FSCP4_CONEMAX,DECIMAL=SML_DEC,XSIZE=SML_FSC_X)
  DHMI_P4_TLB_B     = WIDGET_BASE(DHMI_P4_TLB_3,ROW=1)
  IF WIN_FLAG THEN DHMI_P4_TLB_3_BRID = FSC_FIELD(DHMI_P4_TLB_B,VALUE=CWAVREF,TITLE    ='REFERENCE BAND (NM)               :',OBJECT=FSCP4_WAVREF,XSIZE=SML_FSC_X) $
              ELSE DHMI_P4_TLB_3_BRID = FSC_FIELD(DHMI_P4_TLB_B,VALUE=CWAVREF,TITLE    ='REFERENCE BAND (NM)               :',OBJECT=FSCP4_WAVREF,XSIZE=SML_FSC_X)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_B,VALUE='<',UVALUE='BREF<',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_B,VALUE='>',UVALUE='BREF>',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')  
  IF WIN_FLAG THEN DHMI_P4_TLB_3_CAID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_CALREF,TITLE='ABSOLUTE CAL. AT REF BAND         :',OBJECT=FSCP4_CALREF,DECIMAL=3,XSIZE=SML_FSC_X) $  
              ELSE DHMI_P4_TLB_3_CAID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_CALREF,TITLE='ABSOLUTE CAL. AT REF BAND         :',OBJECT=FSCP4_CALREF,DECIMAL=3,XSIZE=SML_FSC_X)

  IF WIN_FLAG THEN DHMI_P4_TLB_3_TAID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_TAU865,TITLE='AOT AT 865 NM                     :',OBJECT=FSCP4_TAU865,DECIMAL=3,XSIZE=SML_FSC_X) $  
              ELSE DHMI_P4_TLB_3_TAID = FSC_FIELD(DHMI_P4_TLB_3,VALUE=BASE_TAU865,TITLE='AOT AT 865 NM                     :',OBJECT=FSCP4_TAU865,DECIMAL=3,XSIZE=SML_FSC_X)
  DHMI_P4_TLB_AER     = WIDGET_BASE(DHMI_P4_TLB_3,ROW=1)
  IF WIN_FLAG THEN DHMI_P4_TLB_3_AEID = FSC_FIELD(DHMI_P4_TLB_AER,VALUE=CAER,TITLE     ='AEROSOL MODEL                     :',OBJECT=FSCP4_AER) $
              ELSE DHMI_P4_TLB_3_AEID = FSC_FIELD(DHMI_P4_TLB_AER,VALUE=CAER,TITLE     ='AEROSOL MODEL                     :',OBJECT=FSCP4_AER)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_AER,VALUE='<',UVALUE='AER<',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P4_TLB_AER,VALUE='>',UVALUE='AER>',EVENT_PRO='DHMI_PROCESS_4_SETUP_CHANGE')  

;--------------------------
; DEFINE WIDGET TO HOLD START  
; AND EXIT BUTTONS
  
  DHMI_P4_TLB_6       = WIDGET_BASE(DHMI_P4_TLB,ROW=1,/ALIGN_RIGHT)
  DHMI_P4_TLB_6_BTN   = WIDGET_BUTTON(DHMI_P4_TLB_6,VALUE='Start',XSIZE=OPT_BTN,EVENT_PRO='DHMI_PROCESS_4_START')
  DHMI_P4_TLB_6_BTN   = WIDGET_BUTTON(DHMI_P4_TLB_6,VALUE='Exit',XSIZE=OPT_BTN, EVENT_PRO='DHMI_PROCESS_4_EXIT')

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: COMPLETED DEFINING WIDGET'
  IF NOT KEYWORD_SET(GROUP_LEADER) THEN GROUP_LEADER = DHMI_P4_TLB
  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: STORING WIDGET INFO INTO STRUCTURE'
  DHMI_P4_INFO = {$
                  IVERBOSE              : IVERBOSE,$
                  GROUP_LEADER          : GROUP_LEADER,$
                  MAIN_OUTPUT           : MAIN_OUTPUT,$
                  FSCP4_OFOLDER         : FSCP4_OFOLDER,$
                  FSCP4_REGION          : FSCP4_REGION,$
                  ASITE                 : ASITES,$
                  NASITE                : NASITE,$
                  ISITE                 : 0,$
                  FSCP4_SENSOR          : FSCP4_SENSOR,$
                  ASENS                 : ASENS,$
                  NASENS                : NASENS,$
                  ISENS                 : 0,$
                  FSCP4_PROC            : FSCP4_PROC,$
                  APROC                 : APROC,$
                  NAPROC                : NAPROC,$
                  IPROC                 : 0,$
                  FSCP4_YEAR            : FSCP4_YEAR,$
                  AYEAR                 : AYEAR,$
                  NAYEAR                : NAYEAR,$
                  IYEAR                 : 0,$
                  FSCP4_CSP             : FSCP4_CSP,$
                  FSCP4_RIP             : FSCP4_RIP,$
                  CURRENT_BUTTON_PIX    : CURRENT_BUTTON_PIX,$
                  DHMI_P4_TLB_PIX1      : DHMI_P4_TLB_PIX1,$
                  DHMI_P4_TLB_PIX2      : DHMI_P4_TLB_PIX2,$ 
                  FSCP4_AER             : FSCP4_AER,$
                  AAER                  : AAER,$
                  NAER                  : NAER,$
                  IAER                  : 0,$
                  FSCP4_WINDMAX         : FSCP4_WINDMAX,$
                  FSCP4_CONEMAX         : FSCP4_CONEMAX,$
                  FSCP4_BREF            : FSCP4_BREF,$
                  ABREF                 : ABREF,$
                  NBREF                 : NBREF,$
                  IBREF                 : 0,$
                  FSCP4_WAVREF          : FSCP4_WAVREF,$
                  AWAVREF               : AWAVREF,$
                  FSCP4_CALREF          : FSCP4_CALREF,$
                  BASE_BBREF            : BASE_BBREF,$
                  BBREF_MAX             : BBREF_MAX,$
                  CURRENT_BUTTON_CLIM   : CURRENT_BUTTON_CLIM,$
                  DHMI_P4_TLB_CLIM1     : DHMI_P4_TLB_CLIM1,$
                  DHMI_P4_TLB_CLIM2     : DHMI_P4_TLB_CLIM2,$
                  FSCP4_CHL             : FSCP4_CHL,$
                  FSCP4_TAU865          : FSCP4_TAU865 $
                  }
                  
;--------------------------
; REALISE THE WIDGET AND REGISTER WITH THE XMANAGER

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_4: REALISING THE WIDGET AND REGISTERING WITH THE XMANAGER'
  WIDGET_CONTROL,DHMI_P4_TLB,/REALIZE,SET_UVALUE=DHMI_P4_INFO,/NO_COPY,GROUP_LEADER=GROUP_LEADER
  XMANAGER,'DHMI_PROCESS_4',DHMI_P4_TLB

END
