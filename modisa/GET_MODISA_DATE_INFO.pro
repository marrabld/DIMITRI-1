;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      GET_MODISA_DATE_INFO       
;* 
;* PURPOSE:
;*      RETURNS THE DATE INFORMATION OF A MODISA L1B FILE
;* 
;* CALLING SEQUENCE:
;*      RES = GET_MODISA_DATE_INFO(FILENAME,/VERBOSE)      
;* 
;* INPUTS:
;*      FILENAME - FULL PATH OF THE FILE TO BE ANALYSED      
;*
;* KEYWORDS:
;*      VERBOSE - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      DATE_INFO - A STRUCTURE CONTAINING THE YEAR, MONTH, DAY, DAY OF YEAR AND DECIMEL YEAR
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*      03 DEC 2010 - C KENT    - DIMITRI-2 V1.0
;*      14 JUL 2011 - C KENT    - UPDATED TIME EXTRACTION SECTION
;*
;* VALIDATION HISTORY:
;*      03 DEC 2010 - C KENT    - WINDOWS 32-BIT MACHINE IDL 7.1: COMPILATION SUCCESSFUL, 
;*                                RESULTS EQUAL TO HDF EXPLORER
;*      05 JAN 2011 - C KENT    - LINUX 64-BIT MACHINE IDL 8.0: COMPILATION SUCCESSFUL, 
;*                                NO APPARENT DIFFERENCES WHEN COMPARED TO WINDOWS MACHINE
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION GET_MODISA_DATE_INFO,FILENAME,VERBOSE=VERBOSE

;------------------------------------------------
; CHECK FILENAME IS A NOMINAL INPUT

  IF FILENAME EQ '' THEN BEGIN
    PRINT, 'MODISA DATE INFO: ERROR, INPUT FILENAME INCORRECT'
    RETURN,-1
  ENDIF

;------------------------------------------------
; DEFINE OUTPUT STRUCT

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MODISA DATE INFO: DEFINING DATE_INFO STRUCTURE'
  DATE_INFO = {$
              YEAR  :0,$
              MONTH :0,$
              DAY   :0,$
              DOY   :0,$
              DYEAR :DOUBLE(0.0) ,$
              CMD_DATE   :'',$
              CMD_TIME   :'',$
              HOUR  :0,$
              MINUTE:0,$
              SECOND:0 $
              }

;------------------------------------------------
; OPEN HDF FILE AND EXTRACT CORE_METADATA

  HDF_ID = HDF_SD_START(FILENAME,/READ)
  CMETA_ID = HDF_SD_ATTRFIND(HDF_ID,'CoreMetadata.0')
  IF CMETA_ID EQ -1 THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MODISA DATE INFO: ERROR, NO COREMETADATA FOUND'
    RETURN,{ERROR:-1}
  ENDIF
  HDF_SD_ATTRINFO,HDF_ID,CMETA_ID, DATA=HDF_CMD
  
;------------------------------------------------
; CLOSE THE HDF FILE

  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MODISA DATE INFO: RETRIEVED DATA, CLOSING PRODUCT'
  HDF_SD_END, HDF_ID

;------------------------------------------------
; FIND ACQUISITION DATE IN HDF_CMD VARIABLE

  RES = STRPOS(HDF_CMD,'RANGEBEGINNINGDATE')
  IF RES[0] EQ -1 THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MODISA DATE INFO: ERROR, NO RANGEBEGINNINGDATE FOUND'
    RETURN,{ERROR:-1} 
  ENDIF 
  CMD_DATE = STRMID(HDF_CMD,RES+80,10)

  RES = STRPOS(HDF_CMD,'RANGEBEGINNINGTIME')
  IF RES[0] EQ -1 THEN BEGIN
    IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MODISA DATE INFO: ERROR, NO RANGEBEGINNINGTIME FOUND'
    RETURN,{ERROR:-1} 
  ENDIF 
  CMD_TIME = STRMID(HDF_CMD,RES+80,10)

  DATE_INFO.YEAR = FIX(STRMID(CMD_DATE,0,4))
  DATE_INFO.MONTH= FIX(STRMID(CMD_DATE,5,2))
  DATE_INFO.DAY  = FIX(STRMID(CMD_DATE,8,2))
  DATE_INFO.DOY  = JULDAY(DATE_INFO.MONTH,DATE_INFO.DAY,DATE_INFO.YEAR)-JULDAY(1,0,DATE_INFO.YEAR)
  IF FLOAT(DATE_INFO.YEAR) MOD 4 EQ 0 THEN DIY = 366.0 ELSE DIY = 365.0
  
  THR = FIX(STRMID(CMD_TIME,0,2))
  TMM = FIX(STRMID(CMD_TIME,3,2))
  TSS = FIX(STRMID(CMD_TIME,6,2))
  TTIME = DOUBLE((THR/(DIY*24.))+(TMM/(DIY*60.*24.))+TSS/(DIY*60.*60.*24.))

  DATE_INFO.HOUR = THR
  DATE_INFO.MINUTE = TMM
  DATE_INFO.SECOND = TSS
  DATE_INFO.CMD_TIME = CMD_TIME
  DATE_INFO.CMD_DATE = CMD_DATE
  DATE_INFO.DYEAR  = FLOAT(DATE_INFO.YEAR)+(DOUBLE(DATE_INFO.DOY)/DIY)+TTIME
  IF KEYWORD_SET(VERBOSE) THEN PRINT, 'MODISA DATE INFO: DATE RETRIEVAL COMPLETE'

;---------------------------------------
; RETURN DATE INFORMATION

  RETURN,DATE_INFO

END