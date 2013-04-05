;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      DHMI_PROCESS_1    
;* 
;* PURPOSE:
;*      THIS PROGRAM DISPLAYS A WIDGET ALLOWING SPECIFICATION OF THE REQUIRED PARAMETERS 
;*      TO EXTRACT DOUBLETS, INTERCALIBRATE SENSOR CONFIGURATIONS AND RECALIBRATE DATA TO 
;*      A REFERENCE SENSOR 
;*
;* CALLING SEQUENCE:
;*      DHMI_PROCESS_1      
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
;*      17 MAR 2011 - C KENT    - DIMITRI-2 V1.0
;*      21 MAR 2011 - C KENT    - MODIFIED FILE DEFINITION TO USE GET_DIMITRI_LOCATION
;*      22 MAR 2011 - C KENT    - ADDED CONFIGURAITON FILE DEPENDENCE
;*      14 APR 2011 - C KENT    - MINOR BUG FIXES IN LOST SELECTION
;*      06 JUL 2011 - C KENT    - ADDED DATABASE COMMON BLOCK TO DIMITRI HMI
;*
;* VALIDATION HISTORY:
;*      14 APR 2011 - C KENT    - WINDOWS 32-BIT IDL 7.1 AND LINUX 64-BIT IDL 8.0 NOMINAL
;*                                COMPILATION AND OPERATION       
;*
;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_START,EVENT

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY

;---------------------------
; RETRIEVE ALL PARAMETERS

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: RETRIEVING PARAMETERS FROM WIDGET FIELDS' 
  DHMI_P1_INFO.FSCP1_AMC->GETPROPERTY,    VALUE=P1_AMC
  DHMI_P1_INFO.FSCP1_REGION->GETPROPERTY, VALUE=P1_REGION
  DHMI_P1_INFO.FSCP1_SCFIG->GETPROPERTY,  VALUE=P1_SCFIG
  DHMI_P1_INFO.FSCP1_OFOLDER->GETPROPERTY,VALUE=P1_OFOLDER
  DHMI_P1_INFO.FSCP1_DAY->GETPROPERTY,    VALUE=P1_DAYOFFSET
  DHMI_P1_INFO.FSCP1_CSP->GETPROPERTY,    VALUE=P1_CSPERCENT
  DHMI_P1_INFO.FSCP1_RIP->GETPROPERTY,    VALUE=P1_ROIPERCENT
  DHMI_P1_INFO.FSCP1_VZAMIN->GETPROPERTY,    VALUE=P1_VZAMIN
  DHMI_P1_INFO.FSCP1_VZAMAX->GETPROPERTY,    VALUE=P1_VZAMAX
  DHMI_P1_INFO.FSCP1_VAAMIN->GETPROPERTY,    VALUE=P1_VAAMIN
  DHMI_P1_INFO.FSCP1_VAAMAX->GETPROPERTY,    VALUE=P1_VAAMAX
  DHMI_P1_INFO.FSCP1_SZAMIN->GETPROPERTY,    VALUE=P1_SZAMIN
  DHMI_P1_INFO.FSCP1_SZAMAX->GETPROPERTY,    VALUE=P1_SZAMAX
  DHMI_P1_INFO.FSCP1_SAAMIN->GETPROPERTY,    VALUE=P1_SAAMIN
  DHMI_P1_INFO.FSCP1_SAAMAX->GETPROPERTY,    VALUE=P1_SAAMAX

;---------------------------
; SORT OUT OUTPUT FOLDER NAME
 
  IF P1_OFOLDER EQ 'AUTO' THEN BEGIN
  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: CREATING OUTPUTFOLDER NAME'
    DATE        = SYSTIME(/UTC)
    MNTHS       = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
    RES         = WHERE(MNTHS EQ STRUPCASE(STRMID(DATE,4,3)))+1
    IF RES LE 9 THEN RES = '0'+STRTRIM(STRING(RES),2) ELSE RES = STRTRIM(STRING(RES),2)
    DD = FIX(STRMID(DATE,8,2)) LE 9 ?  '0'+STRMID(DATE,9,1):STRMID(DATE,8,2)
    DATE        = STRMID(DATE,20,4)+RES+DD
    P1_OFOLDER  = DHMI_P1_INFO.MAIN_OUTPUT+P1_REGION+'_'+DATE+'_REF_'+P1_SCFIG
  ENDIF ELSE P1_OFOLDER = DHMI_P1_INFO.MAIN_OUTPUT+STRJOIN(STRSPLIT(P1_OFOLDER,' ',/EXTRACT),'_')

;---------------------------
; CHECK OUTPUT FOLDER 

  IF FILE_TEST(P1_OFOLDER,/DIRECTORY) EQ 1 THEN BEGIN
    MSG = ['OUTPUT FOLDER ALREADY EXISTS','OVERWRITE DATA?']
    MSG = DIALOG_MESSAGE(MSG,/QUESTION,/CENTER)
    IF STRCMP(STRUPCASE(MSG),'NO') EQ 1 THEN BEGIN
      P1_OFOLDER  = P1_OFOLDER+'_1'
      I = 2
      SCHECK = 0
      WHILE SCHECK EQ 0 DO BEGIN
        
        P1_OFOLDER = STRSPLIT(P1_OFOLDER,'_',/EXTRACT)
        P1_OFOLDER[N_ELEMENTS(P1_OFOLDER)-1] = STRTRIM(STRING(I),2)
        P1_OFOLDER = STRJOIN(P1_OFOLDER,'_')
        
        IF FILE_TEST(P1_OFOLDER,/DIRECTORY) EQ 0 THEN SCHECK = 1
        I++
      ENDWHILE
    ENDIF
  ENDIF

;---------------------------
; GET A LIST OF ALL PROCESSOR 
; CONFIGS SELECTED

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: RETRIEVING LIST OF SELECTED CONFIGURATIONS'
  RES = WHERE(DHMI_P1_INFO.LIST2 NE '',COUNT)
  IF COUNT GT 0 THEN P1_CONFIGS = DHMI_P1_INFO.LIST2[RES] ELSE BEGIN
    PRINT, 'DHMI_PROCESS_1->START: ERROR, NO SENSOR CONFIGS SELECTED'
    GOTO,NO_SELECTION
  ENDELSE

  NCONFIGS    = N_ELEMENTS(P1_CONFIGS)
  P1_CAL_SENS = MAKE_ARRAY(/STRING,NCONFIGS)
  P1_CAL_CFIG = MAKE_ARRAY(/STRING,NCONFIGS)
  P1_REF_SENS = MAKE_ARRAY(/STRING,NCONFIGS)
  P1_REF_CFIG = MAKE_ARRAY(/STRING,NCONFIGS)

;---------------------------
; SPLIT CONFIGURATIONS INTO 
; SENSOR AND PROC_VERSIONS

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: RETRIEVING SENSOR NAMES AND PROC VERS'
  FOR I=0,NCONFIGS-1 DO BEGIN
    RES = STRPOS(P1_CONFIGS[I],'_')
    P1_CAL_SENS[I] = STRMID(P1_CONFIGS[I],0,RES)
    P1_CAL_CFIG[I] = STRMID(P1_CONFIGS[I],RES+1,STRLEN(P1_CONFIGS[I])-RES-1)
  ENDFOR

  RES = STRPOS(P1_SCFIG,'_')
  P1_REF_SENS[*] = STRMID(P1_SCFIG,0,RES)
  P1_REF_CFIG[*] = STRMID(P1_SCFIG,RES+1,STRLEN(P1_SCFIG)-RES-1)

;--------------------------
; GET SCREEN DIMENSIONS FOR 
; CENTERING INFO WIDGET

  DIMS  = GET_SCREEN_SIZE()
  XSIZE = 200
  YSIZE = 60
  XLOC  = (DIMS[0]/2)-(XSIZE/2)
  YLOC  = (DIMS[1]/2)-(YSIZE/2)

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: CREATING AN INFO WIDGET'
  INFO_WD = WIDGET_BASE(COLUMN=1, XSIZE=XSIZE, YSIZE=YSIZE, TITLE='Please Wait...',XOFFSET=XLOC,YOFFSET=YLOC)
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE=' ')
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE='Please wait,')
  LBLTXT  = WIDGET_LABEL(INFO_WD,VALUE='Processing...')
  WIDGET_CONTROL, INFO_WD, /REALIZE
  WIDGET_CONTROL, /HOURGLASS

;--------------------------
; LOOP OVER EACH CAL SENSOR 
; AND EXTRACT DOUBLETS

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: EXTRACTING DOUBLETS FOR EACH CONFIGURATION'  
  FOR DHMI_I=0,NCONFIGS-1 DO BEGIN
    RES = DIMITRI_INTERFACE_DOUBLET(P1_OFOLDER,P1_REGION,P1_REF_SENS[DHMI_I],P1_REF_CFIG[DHMI_I],P1_CAL_SENS[DHMI_I],$
                                      P1_CAL_CFIG[DHMI_I],P1_AMC,P1_DAYOFFSET,P1_CSPERCENT,P1_ROIPERCENT, $
                                      P1_VZAMIN,P1_VZAMAX,P1_VAAMIN,P1_VAAMAX,P1_SZAMIN,P1_SZAMAX,P1_SAAMIN,P1_SAAMAX, $
                                      VERBOSE=DHMI_P1_INFO.IVERBOSE)
  
  ENDFOR

;--------------------------
; CALL INTERCALIBRATION ROUTINE

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: CALLING INTERCALIBRATION ROUTINE'
  RES = DIMITRI_INTERFACE_INTERCALIBRATION(P1_OFOLDER,P1_REGION,P1_REF_SENS,P1_REF_CFIG,P1_CAL_SENS,$
                                            P1_CAL_CFIG,DHMI_P1_INFO.DIMITRI_BDS,VERBOSE=DHMI_P1_INFO.IVERBOSE)

  IF RES EQ -1 THEN BEGIN
   MSG = ['DIMITRI PROCESS 1:','ERROR DURRING INTERCAL']
   TMP = DIALOG_MESSAGE(MSG,/INFORMATION,/CENTER)
   GOTO,P1_ERR
  ENDIF

;--------------------------
; CALL RECALIBRATION ROUTINE

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: CALLING RECALIBRATION ROUTINE'
  RES = DIMITRI_INTERFACE_RECALIBRATION(P1_OFOLDER,P1_REGION,P1_REF_SENS,P1_REF_CFIG,P1_CAL_SENS,$
                                          P1_CAL_CFIG,P1_CSPERCENT,P1_ROIPERCENT,                $
                                          P1_VZAMIN,P1_VZAMAX,P1_VAAMIN,P1_VAAMAX,P1_SZAMIN,P1_SZAMAX,P1_SAAMIN,P1_SAAMAX, $
                                          VERBOSE=DHMI_P1_INFO.IVERBOSE)
;--------------------------
; DESTROY INFO WIDGET AND RETURN 
; TO PROCESS_1 WIDGET

  P1_ERR:
  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->START: DESTROYING INFO WIDGET AND RETURNING'
  WIDGET_CONTROL,INFO_WD,/DESTROY
  NO_SELECTION:
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_EXIT,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY
  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->EXIT: DESTROYING OBJECTS'

;--------------------------
; DESTROY OBJECTS

  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_SZA
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_VZA
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_RAA
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_AMC
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_REGION
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_SCFIG
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_OFOLDER
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_DAY
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_CSP
  OBJ_DESTROY,DHMI_P1_INFO.FSCP1_RIP

;--------------------------
; DESTROY THE WIDGET

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->EXIT: DESTROYING PROCESS 1 WIDGET'
  WIDGET_CONTROL,EVENT.TOP,/DESTROY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_UPDATE_AMC,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION
  
  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY

;--------------------------
; RETRIEVE SZA,VZA AND RAA INFORMATION

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->AMC: RETRIEVING SZA,VZA,RAA FROM WIDGET'
  DHMI_P1_INFO.FSCP1_SZA->GETPROPERTY, VALUE=TEMP_SZA
  DHMI_P1_INFO.FSCP1_VZA->GETPROPERTY, VALUE=TEMP_VZA
  DHMI_P1_INFO.FSCP1_RAA->GETPROPERTY, VALUE=TEMP_RAA

;--------------------------
; COMPUTE NEW THRESHOLD

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->AMC: RECOMPUTING AMC THRESHOLD'
  TMP_AMC = COMPUTE_AMC_THRESHOLD(TEMP_SZA,TEMP_VZA,TEMP_RAA,VERBOSE=VERBOSE)
  
;--------------------------
; UPDATE VALUE AND RETURN
  
  DHMI_P1_INFO.FSCP1_AMC->SETPROPERTY, VALUE=TMP_AMC
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_LIST1,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION
  
  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY

;--------------------------
; UPDATE SELECTION

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->LIST1: UPDATING LIST 1 SELECTION'
  DHMI_P1_INFO.CURRENT_SELECTION_L1 = DHMI_P1_INFO.USENFIG[EVENT.INDEX]
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_LIST2,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION
  
  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY

;--------------------------
; UPDATE SELECTION

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->LIST2: UPDATING LIST 2 SELECTION'
  DHMI_P1_INFO.CURRENT_SELECTION_L2 = DHMI_P1_INFO.LIST2[EVENT.INDEX]
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_UPDATE_SCS,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION
  
  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY
  WIDGET_CONTROL, EVENT.ID,   GET_UVALUE=ACTION

;--------------------------
; DETERMINE WHICH BUTTON PRESSED

  CASE ACTION OF
  '>>': BEGIN
          IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->SCS: ADDING SELECTION TO LIST 2'
          IF DHMI_P1_INFO.CURRENT_SELECTION_L1 NE '' THEN BEGIN
            RES = WHERE(DHMI_P1_INFO.LIST2 EQ DHMI_P1_INFO.CURRENT_SELECTION_L1,COUNT)
            IF COUNT GT 0 THEN BEGIN
              MSG = 'CONFIGURATION ALREADY SELECTED'
              RES = DIALOG_MESSAGE(MSG,/INFORMATION)
              GOTO, NO_UPDATE
            ENDIF
            RES = WHERE(DHMI_P1_INFO.LIST2 EQ '')
            DHMI_P1_INFO.LIST2[RES(0)] = DHMI_P1_INFO.CURRENT_SELECTION_L1
          ENDIF
        END
  '<<': BEGIN
          IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->SCS: REMOVING SELECTION FROM LIST 2'
          IF DHMI_P1_INFO.CURRENT_SELECTION_L2 NE '' THEN BEGIN
            RES = WHERE(DHMI_P1_INFO.LIST2 EQ DHMI_P1_INFO.CURRENT_SELECTION_L2)
            IF RES[0] GT -1 THEN BEGIN
            DHMI_P1_INFO.LIST2[RES] = ''
            DHMI_P1_INFO.LIST2[RES:N_ELEMENTS(DHMI_P1_INFO.LIST2)-2] = DHMI_P1_INFO.LIST2[$
                                                                        RES+1:N_ELEMENTS(DHMI_P1_INFO.LIST2)-1]
            DHMI_P1_INFO.LIST2[N_ELEMENTS(DHMI_P1_INFO.LIST2)-1] = ''
            ENDIF
          ENDIF
        END
  ENDCASE

;--------------------------
; UPDATE LIST VALUE AND RETURN TO WIDGET

  NO_UPDATE:
  WIDGET_CONTROL,DHMI_P1_INFO.DHMI_P1_TLB_2_L2,SET_VALUE=DHMI_P1_INFO.LIST2
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_UPDATE_ROI,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY
  WIDGET_CONTROL, EVENT.ID,   GET_UVALUE=ACTION

;--------------------------
; UPDATE THE ROI FIELD INDEX

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->ROI: UPDATING REGION OF INTEREST FIELD'
  CASE ACTION OF
    '>':DHMI_P1_INFO.ISITES = DHMI_P1_INFO.ISITES+1
    '<':DHMI_P1_INFO.ISITES = DHMI_P1_INFO.ISITES-1
  ENDCASE
  IF DHMI_P1_INFO.ISITES LT 0 THEN DHMI_P1_INFO.ISITES = N_ELEMENTS(DHMI_P1_INFO.USITES)-1
  IF DHMI_P1_INFO.ISITES EQ N_ELEMENTS(DHMI_P1_INFO.USITES) THEN DHMI_P1_INFO.ISITES = 0 

;--------------------------
; UPDATE THE ROI VALUE

  DHMI_P1_INFO.FSCP1_REGION->SETPROPERTY, VALUE=DHMI_P1_INFO.USITES[DHMI_P1_INFO.ISITES]

;--------------------------
; RETRIEVE AVAILABLE CONFIGURATIONS FOR THIS REGION

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->SCS: UPDATING AVAILABLE REFERENCE CONFIGURATIONS'
  DHMI_P1_INFO.ASENFIG[*] = ''
  RES   = WHERE(DHMI_P1_INFO.REGION_LIST EQ DHMI_P1_INFO.USITES[DHMI_P1_INFO.ISITES])
  TEMP  = DHMI_P1_INFO.SENSOR_CFIGS[RES]
  TEMP  = TEMP(UNIQ(TEMP,SORT(TEMP)))
  DHMI_P1_INFO.NASENFIG = N_ELEMENTS(TEMP)
  DHMI_P1_INFO.ASENFIG[0:DHMI_P1_INFO.NASENFIG-1] = TEMP
  DHMI_P1_INFO.ISENFIG = 0

;--------------------------
; UPDATE VALUES AND RETURN TO WIDGET

  DHMI_P1_INFO.FSCP1_SCFIG->SETPROPERTY, VALUE=DHMI_P1_INFO.ASENFIG[DHMI_P1_INFO.ISENFIG]
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1_UPDATE_RCFIG,EVENT

;--------------------------
; RETRIEVE WIDGET INFORMATION

  WIDGET_CONTROL, EVENT.TOP,  GET_UVALUE=DHMI_P1_INFO, /NO_COPY
  WIDGET_CONTROL, EVENT.ID,   GET_UVALUE=ACTION

;--------------------------
; UPDATE CONFIGURAITON INDEX

  IF DHMI_P1_INFO.IVERBOSE EQ 1 THEN PRINT,'DHMI_PROCESS_1->SCS: UPDATING REFERENCE CONFIGURATION VALUE'
  CASE ACTION OF
    '>':DHMI_P1_INFO.ISENFIG = DHMI_P1_INFO.ISENFIG+1
    '<':DHMI_P1_INFO.ISENFIG = DHMI_P1_INFO.ISENFIG-1
  ENDCASE
  IF DHMI_P1_INFO.ISENFIG LT 0 THEN DHMI_P1_INFO.ISENFIG = DHMI_P1_INFO.NASENFIG-1
  IF DHMI_P1_INFO.ISENFIG EQ DHMI_P1_INFO.NASENFIG THEN DHMI_P1_INFO.ISENFIG = 0 

;--------------------------
; UPDATE CONFIGURATION VALUE AND RETURN

  DHMI_P1_INFO.FSCP1_SCFIG->SETPROPERTY, VALUE=DHMI_P1_INFO.ASENFIG[DHMI_P1_INFO.ISENFIG]
  WIDGET_CONTROL, EVENT.TOP, SET_UVALUE=DHMI_P1_INFO, /NO_COPY

END

;**************************************************************************************
;**************************************************************************************

PRO DHMI_PROCESS_1,GROUP_LEADER=GROUP_LEADER,VERBOSE=VERBOSE

COMMON DHMI_DATABASE

;--------------------------
; FIND MAIN DIMITRI FOLDER AND DELIMITER

  IF KEYWORD_SET(VERBOSE) THEN BEGIN
    PRINT,'DHMI_PROCESS_1: STARTING PROCESS 1 HMI ROUTINE'
    IVERBOSE=1
  ENDIF ELSE IVERBOSE=0
  IF STRUPCASE(!VERSION.OS_FAMILY) EQ 'WINDOWS' THEN WIN_FLAG = 1 ELSE WIN_FLAG = 0
 
  DL          = GET_DIMITRI_LOCATION('DL')
  MAIN_OUTPUT = GET_DIMITRI_LOCATION('OUTPUT')
  SBI_FILE    = GET_DIMITRI_LOCATION('BAND_INDEX')

;--------------------------
; RETRIEVE NUMBER OF DIMITRI BANDS

  TEMP        = GET_DIMITRI_BAND_INDEX_TEMPLATE()
  BI_DATA     = READ_ASCII(SBI_FILE,TEMPLATE=TEMP)
  N_DBS       = N_ELEMENTS(BI_DATA.(0))
  DIMITRI_BDS = INDGEN(N_DBS)

;--------------------------
; GET LIST OF ALL SITES, SENSORS 
; AND PROCESSING VERSIONS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: RETRIVEING UNIQ REGIONS AND SENSOR CONFIGS'
  ISITES = 0
  ISENFIG = 0

  USITES        = DHMI_DB_DATA.REGION[UNIQ(DHMI_DB_DATA.REGION,SORT(DHMI_DB_DATA.REGION))]
  SENSOR_CFIGS  = DHMI_DB_DATA.SENSOR+'_'+DHMI_DB_DATA.PROCESSING_VERSION
  USENFIG       = SENSOR_CFIGS[UNIQ(SENSOR_CFIGS,SORT(SENSOR_CFIGS))]

;--------------------------
; GET CONFIGURATIONS AVAILABLE FOR FIRST REFERENCE SENSOR

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: RETRIVEING SENSOR CONFIGS FOR FIRST REGION'
  RES       = WHERE(DHMI_DB_DATA.REGION EQ USITES[0],COUNT)
  ASENFIG   = MAKE_ARRAY(N_ELEMENTS(USENFIG),/STRING)
  TMP       = SENSOR_CFIGS[UNIQ(SENSOR_CFIGS[RES],SORT(SENSOR_CFIGS[RES]))]
  NASENFIG  = N_ELEMENTS(TMP)
  ASENFIG[0:NASENFIG-1] = TMP
  LIST2     = MAKE_ARRAY(N_ELEMENTS(USENFIG),/STRING)

;--------------------------
; DEFINE BASE PARAMETERS

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: DEFINING BASE PARAMETERS'
  CFIG_DATA = GET_DIMITRI_CONFIGURATION() 
  BASE_SZA  = CFIG_DATA.(1)[5]
  BASE_VZA  = CFIG_DATA.(1)[4]
  BASE_RAA  = CFIG_DATA.(1)[6]
  BASE_AMC  = COMPUTE_AMC_THRESHOLD(BASE_SZA,BASE_VZA,BASE_RAA)

  BASE_DAY  = CFIG_DATA.(1)[9]
  BASE_CLOUD= CFIG_DATA.(1)[7]
  BASE_ROI  = CFIG_DATA.(1)[8] 
  
  OPT_BTN   = 60
  SML_BTNX  = 30
  SML_BTNY  = 10 
  SML_DEC   = 2
  SML_FSC_X = 7

;--------------------------
; DEFINE THE MAIN WIDGET 

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: RETRIEVING SCREEN DIMENSIONS FOR WIDGET'
  DIMS  = GET_SCREEN_SIZE()
  IF WIN_FLAG THEN XSIZE = 425 ELSE XSIZE = 490
  YSIZE = 800
  XLOC  = (DIMS[0]/2)-(XSIZE/2)
  YLOC  = (DIMS[1]/2)-(YSIZE/2)

  DHMI_P1_TLB = WIDGET_BASE(COLUMN=1,TITLE='DIMITRI V2.0: SENSOR RECAL SETUP',XSIZE=XSIZE,$
                                  XOFFSET=XLOC,YOFFSET=YLOC)
;--------------------------
; DEFINE WIDGET TO HOLD OUTPUTFOLDER,
; REGION AND REF CONFIGURATION

  DHMI_P1_TLB_1 = WIDGET_BASE(DHMI_P1_TLB,ROW=3)
  IF WIN_FLAG THEN DHMI_P1_TLB_1_OFID = FSC_FIELD(DHMI_P1_TLB_1,VALUE='AUTO',TITLE='FOLDER         :',OBJECT=FSCP1_OFOLDER) $
    ELSE DHMI_P1_TLB_1_OFID = FSC_FIELD(DHMI_P1_TLB_1,VALUE='AUTO',TITLE='FOLDER     : ',OBJECT=FSCP1_OFOLDER) 
  DHMI_BLK      = WIDGET_LABEL(DHMI_P1_TLB_1,VALUE='')
  DHMI_BLK      = WIDGET_LABEL(DHMI_P1_TLB_1,VALUE='')

  IF WIN_FLAG THEN DHMI_P1_TLB_1_RGID = FSC_FIELD(DHMI_P1_TLB_1,VALUE=USITES[0],TITLE='REF REGION :',OBJECT=FSCP1_REGION) $
    ELSE DHMI_P1_TLB_1_RGID = FSC_FIELD(DHMI_P1_TLB_1,VALUE=USITES[0],TITLE='REF REGION : ',OBJECT=FSCP1_REGION)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P1_TLB_1,VALUE='<',UVALUE='<',EVENT_PRO='DHMI_PROCESS_1_UPDATE_ROI')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P1_TLB_1,VALUE='>',UVALUE='>',EVENT_PRO='DHMI_PROCESS_1_UPDATE_ROI')  
  
  IF WIN_FLAG THEN DHMI_P1_TLB_1_SCID = FSC_FIELD(DHMI_P1_TLB_1,VALUE=ASENFIG[0],TITLE='REF SENSOR:',OBJECT=FSCP1_SCFIG) $
    ELSE DHMI_P1_TLB_1_SCID = FSC_FIELD(DHMI_P1_TLB_1,VALUE=ASENFIG[0],TITLE='REF SENSOR : ',OBJECT=FSCP1_SCFIG)
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P1_TLB_1,VALUE='<',UVALUE='<',EVENT_PRO='DHMI_PROCESS_1_UPDATE_RCFIG')
  DHMI_BLK      = WIDGET_BUTTON(DHMI_P1_TLB_1,VALUE='>',UVALUE='>',EVENT_PRO='DHMI_PROCESS_1_UPDATE_RCFIG')  

;--------------------------  
; DEFINE LIST WIDGETS AND BUTTONS 
; FOR ADDING/REMOVING CONFIGS

  DHMI_P1_TLB_2     = WIDGET_BASE(DHMI_P1_TLB,COLUMN=1,FRAME=1)
  DHMI_P1_TLB_2_LBL = WIDGET_LABEL(DHMI_P1_TLB_2,VALUE='SENSOR CONFIGURATION SELECTION :',/ALIGN_LEFT)
  DHMI_P1_TLB_2A    = WIDGET_BASE(DHMI_P1_TLB_2,ROW=1)
  DHMI_P1_TLB_2_L1  = WIDGET_LIST(DHMI_P1_TLB_2A,VALUE=USENFIG, XSIZE=SML_BTNX,YSIZE=SML_BTNY,$
                                    EVENT_PRO='DHMI_PROCESS_1_LIST1')
  DHMI_P1_TLB_2B    = WIDGET_BASE(DHMI_P1_TLB_2A,COLUMN=1,/ALIGN_CENTER)
  DHMI_P1_TLB_2_BTN = WIDGET_BUTTON(DHMI_P1_TLB_2B,VALUE='>>',UVALUE='>>',EVENT_PRO='DHMI_PROCESS_1_UPDATE_SCS')
  DHMI_P1_TLB_2_BTN = WIDGET_BUTTON(DHMI_P1_TLB_2B,VALUE='<<',UVALUE='<<',EVENT_PRO='DHMI_PROCESS_1_UPDATE_SCS')
  DHMI_P1_TLB_2_L2  = WIDGET_LIST(DHMI_P1_TLB_2A,VALUE=LIST2,   XSIZE=SML_BTNX,YSIZE=SML_BTNY,$
                                    EVENT_PRO='DHMI_PROCESS_1_LIST2')

;-------------------------- 
; DEFINE WIDGET TO HOLD AMC VALUES

  DHMI_P1_TLB_3       = WIDGET_BASE(DHMI_P1_TLB,ROW=3,FRAME=1)
  DHMI_P1_TLB_3_LBL   = WIDGET_LABEL(DHMI_P1_TLB_3,VALUE='ANGULAR MATCHING CRITERIA:',/ALIGN_LEFT)
  DHMI_P1_TLB_3AA     = WIDGET_BASE(DHMI_P1_TLB_3,COLUMN=1,XSIZE=XSIZE-20) 
  DHMI_P1_TLB_3A      = WIDGET_BASE(DHMI_P1_TLB_3AA,row=1,/align_center)  
  DHMI_P1_TLB_3_SZAID = FSC_FIELD(DHMI_P1_TLB_3A,VALUE=BASE_SZA,TITLE='SZA:',OBJECT=FSCP1_SZA,$
                                    DECIMAL=SML_DEC,XSIZE=SML_FSC_X,/align_center)
  DHMI_P1_TLB_3_VZAID = FSC_FIELD(DHMI_P1_TLB_3A,VALUE=BASE_VZA,TITLE='VZA:',OBJECT=FSCP1_VZA,$
                                    DECIMAL=SML_DEC,XSIZE=SML_FSC_X,/align_center)
  DHMI_P1_TLB_3_RAAID = FSC_FIELD(DHMI_P1_TLB_3A,VALUE=BASE_RAA,TITLE='RAA:',OBJECT=FSCP1_RAA,$
                                    DECIMAL=SML_DEC,XSIZE=SML_FSC_X,/align_center)  

  DHMI_P1_TLB_3B      = WIDGET_BASE(DHMI_P1_TLB_3AA,ROW=1,/align_center)
  DHMI_P1_TLB_3_BTN   = WIDGET_BUTTON(DHMI_P1_TLB_3B,VALUE='UPDATE AMC',EVENT_PRO='DHMI_PROCESS_1_UPDATE_AMC')
  DHMI_P1_TLB_3_AMCID = FSC_FIELD(DHMI_P1_TLB_3B,VALUE=BASE_AMC,TITLE='AMC:',OBJECT=FSCP1_AMC)


;--------------------------
; DEFINE WIDGET FOR ABSOLUTE ANGLE CRITERIA

  DHMI_P1_TLB_4       = WIDGET_BASE(DHMI_P1_TLB,ROW=2,FRAME=1)
  DHMI_P1_TLB_4_LBL   = WIDGET_LABEL(DHMI_P1_TLB_4,VALUE='ABSOLUTE MATCHING CRITERIA:',/ALIGN_LEFT)
  DHMI_P1_TLB_4_FD    = WIDGET_BASE(DHMI_P1_TLB_4,column=1,XSIZE=XSIZE-20)
  DHMI_P1_TLB_4_FD2   = WIDGET_BASE(DHMI_P1_TLB_4_FD,ROW=5,/ALIGN_CENTER)
  
  IF WIN_FLAG THEN STR = '                   MIN              MAX' $
    ELSE STR = '            MIN          MAX'
  
        DHMI_BLK      = WIDGET_LABEL(DHMI_P1_TLB_4_FD2,VALUE=STR,YSIZE=20,/ALIGN_CENTER)
        DHMI_BLK      = WIDGET_LABEL(DHMI_P1_TLB_4_FD2,VALUE='',YSIZE=20,/ALign_center)

        DHMI_P1_TLB_4_VZALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=0,OBJECT=FSCP1_VZAMIN,XSIZE=SML_FSC_X,TITLE='VZA  :  ',/align_center)
        DHMI_P1_TLB_4_VZAUID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=90,OBJECT=FSCP1_VZAMAX,XSIZE=SML_FSC_X,TITLE='',/align_center)

        DHMI_P1_TLB_4_VAALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=0,OBJECT=FSCP1_VAAMIN,XSIZE=SML_FSC_X,TITLE='VAA  :  ',/align_center)
        DHMI_P1_TLB_4_VAALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=360,OBJECT=FSCP1_VAAMAX,XSIZE=SML_FSC_X,TITLE='',/align_center)
        
        DHMI_P1_TLB_4_SZALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=0,OBJECT=FSCP1_SZAMIN,XSIZE=SML_FSC_X,TITLE='SZA  :  ',/align_center)
        DHMI_P1_TLB_4_SZALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=90,OBJECT=FSCP1_SZAMAX,XSIZE=SML_FSC_X,TITLE='',/align_center)

        DHMI_P1_TLB_4_SAALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=0,OBJECT=FSCP1_SAAMIN,XSIZE=SML_FSC_X,TITLE='SAA  :  ',/align_center)
        DHMI_P1_TLB_4_SAALID= FSC_FIELD(DHMI_P1_TLB_4_FD2,VALUE=360,OBJECT=FSCP1_SAAMAX,XSIZE=SML_FSC_X,TITLE='',/align_center)
        
;--------------------------
; DEFINE WIDGET TO HOLD DAY, 
; CLOUD AND ROI PARAMETERS

  DHMI_P1_TLB_5       = WIDGET_BASE(DHMI_P1_TLB,COLUMN=1,FRAME=1)
  DHMI_P1_TLB_5_LBL   = WIDGET_LABEL(DHMI_P1_TLB_5,VALUE='TEMPORAL AND COVERAGE CRITERIA :',/ALIGN_LEFT)
  DHMI_P1_TLB_5_FD    = WIDGET_BASE(DHMI_P1_TLB_5,ROW=1)
  IF WIN_FLAG THEN DHMI_P1_TLB_5_DAYID = FSC_FIELD(DHMI_P1_TLB_5_FD,VALUE=FIX(BASE_DAY),TITLE='DAY OFFSET :',OBJECT=FSCP1_DAY,XSIZE=SML_FSC_X) $
    ELSE DHMI_P1_TLB_5_DAYID = FSC_FIELD(DHMI_P1_TLB_5_FD,VALUE=FIX(BASE_DAY),TITLE='DAY OFFSET : ',OBJECT=FSCP1_DAY,XSIZE=SML_FSC_X)
  IF WIN_FLAG THEN DHMI_P1_TLB_5_CSPID = FSC_FIELD(DHMI_P1_TLB_5_FD,VALUE=BASE_CLOUD,TITLE='CLOUD %       :',OBJECT=FSCP1_CSP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X) $
    ELSE DHMI_P1_TLB_5_CSPID = FSC_FIELD(DHMI_P1_TLB_5_FD,VALUE=BASE_CLOUD,TITLE='CLOUD %    : ',OBJECT=FSCP1_CSP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X)
  IF WIN_FLAG THEN DHMI_P1_TLB_5_RIPID = FSC_FIELD(DHMI_P1_TLB_5_FD,VALUE=BASE_ROI,TITLE='REGION %     :',OBJECT=FSCP1_RIP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X) $  
    ELSE DHMI_P1_TLB_5_RIPID = FSC_FIELD(DHMI_P1_TLB_5_FD,VALUE=BASE_ROI,TITLE='REGION %   : ',OBJECT=FSCP1_RIP,DECIMAL=SML_DEC,XSIZE=SML_FSC_X)

;--------------------------
; DEFINE WIDGET TO HOLD START  
; AND EXIT BUTTONS
  
  DHMI_P1_TLB_6       = WIDGET_BASE(DHMI_P1_TLB,ROW=1,/ALIGN_RIGHT)
  DHMI_P1_TLB_6_BTN   = WIDGET_BUTTON(DHMI_P1_TLB_6,VALUE='Start',XSIZE=OPT_BTN,EVENT_PRO='DHMI_PROCESS_1_START')
  DHMI_P1_TLB_6_BTN   = WIDGET_BUTTON(DHMI_P1_TLB_6,VALUE='Exit',XSIZE=OPT_BTN, EVENT_PRO='DHMI_PROCESS_1_EXIT')

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: COMPLETED DEFINING WIDGET'
  IF NOT KEYWORD_SET(GROUP_LEADER) THEN GROUP_LEADER = DHMI_P1_TLB
  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: STROING WIDGET INFO INTO STRUCTURE'
  DHMI_P1_INFO = {$
                  IVERBOSE              : IVERBOSE,$
                  DIMITRI_BDS           : DIMITRI_BDS,$
                  SENSOR_CFIGS          : SENSOR_CFIGS,$
                  REGION_LIST           : DHMI_DB_DATA.REGION,$
                  MAIN_OUTPUT           : MAIN_OUTPUT,$
                  FSCP1_DAY             : FSCP1_DAY,$
                  FSCP1_CSP             : FSCP1_CSP,$
                  FSCP1_RIP             : FSCP1_RIP,$
                  FSCP1_OFOLDER         : FSCP1_OFOLDER,$
                  FSCP1_SCFIG           : FSCP1_SCFIG,$
                  FSCP1_REGION          : FSCP1_REGION,$
                  ASENFIG               : ASENFIG,$
                  NASENFIG              : NASENFIG,$
                  USITES                : USITES,$
                  ISITES                : ISITES, $
                  FSCP1_SZA             : FSCP1_SZA, $
                  FSCP1_VZA             : FSCP1_VZA, $
                  FSCP1_RAA             : FSCP1_RAA, $
                  FSCP1_AMC             : FSCP1_AMC, $
                  USENFIG               : USENFIG,$
                  ISENFIG               : ISENFIG,$
                  LIST2                 : LIST2,$
                  DHMI_P1_TLB_2_L2      : DHMI_P1_TLB_2_L2,$
                  FSCP1_VZAMIN          : FSCP1_VZAMIN,$
                  FSCP1_VZAMAX          : FSCP1_VZAMAX,$
                  FSCP1_VAAMIN          : FSCP1_VAAMIN,$
                  FSCP1_VAAMAX          : FSCP1_VAAMAX,$
                  FSCP1_SZAMIN          : FSCP1_SZAMIN,$
                  FSCP1_SZAMAX          : FSCP1_SZAMAX,$
                  FSCP1_SAAMIN          : FSCP1_SAAMIN,$
                  FSCP1_SAAMAX          : FSCP1_SAAMAX,$
                  CURRENT_SELECTION_L1  : '', $
                  CURRENT_SELECTION_L2  : '' $
                  }
                  
;--------------------------
; REALISE THE WIDGET AND REGISTER WITH THE XMANAGER

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'DHMI_PROCESS_1: REALISING THE WIDGET AND REGISTERING WITH THE XMANAGER'
  WIDGET_CONTROL,DHMI_P1_TLB,/REALIZE,SET_UVALUE=DHMI_P1_INFO,/NO_COPY,GROUP_LEADER=GROUP_LEADER
  XMANAGER,'DHMI_PROCESS_1',DHMI_P1_TLB

END