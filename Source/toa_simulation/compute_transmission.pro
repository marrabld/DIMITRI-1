;**************************************************************************************
;**************************************************************************************
;*
;* NAME:
;*      COMPUTE_TRANSMISSION    
;* 
;* PURPOSE:
;*      THIS FUNCTION COMPUTES THE TOTAL TRANSMISSION (UPWELLING AND DOWNWELLING) DUE 
;*      TO OZONE, WATER VAPOUR AND GASEOUS ABSORPTION
;*
;* CALLING SEQUENCE:
;*      RES = COMPUTE_TRANSMISSION(TO3,O3,TH2O,WV,TGAS,THETAS,THETAV)
;* 
;* INPUTS:
;*      TO3     - A SCALAR OR ARRAY OF OZONE TRANSMISSION VALUES
;*      O3      - A SCALAR VALUE OF THE OZONE CONCENTRATION      
;*      TH2O    - A SCALAR OR ARRAY OF OZONE TRANSMISSION VALUES
;*      WV      - A SCALAR VALUE OF THE WATER VAPOUR CONCENTRATION  
;*      TGAS    - A SCALAR OR ARRAY OF GASEOUS TRANSMISSION VALUES
;*      THETAS  - A SCALAR VALUE OF THE SOLAR ZENITH ANGLE IN DEGREES
;*      THETAV  - A SCALAR VALUE OF THE VIEWING ZENITH ANGLE IN DEGREES
;*
;*      NOTE, T03,TH2O AND TGAS MUST BE OF THE SAME NUMER OF ELEMENTS
;*
;* KEYWORDS:
;*      VERBOSE   - PROCESSING STATUS OUTPUTS
;*
;* OUTPUTS:
;*      TRANS_2   - THE COMPUTED TRANSMISSION VALUE(S)
;*
;* COMMON BLOCKS:
;*      NONE
;*
;* MODIFICATION HISTORY:
;*      20 APR 2011 - C KENT   - DIMITRI-2 V1.0
;*
;* VALIDATION HISTORY:
;*      
;*
;**************************************************************************************
;**************************************************************************************

FUNCTION COMPUTE_TRANSMISSION,TO3,O3,TH2O,WV,TGAS,THETAS,THETAV,VERBOSE=VERBOSE

;---------------------------
; DEFINE DEFUALT PARAMETERS

  REF_O3 = 300.0
  REF_WV = 2.0

;---------------------------
; COMPUTE TEMPORARY PARAMETERS

  TEMP_OZONE  = TO3*(O3/REF_O3)
  TEMP_WV     = TH2O*(WV/REF_WV)
  TEMP_ANG    = (1./COS(THETAS*!DTOR))+(1./COS(THETAV*!DTOR))

;---------------------------
; COMBINE INTO FINAL TRANSMISSION

  TRANS_1 = -(TEMP_OZONE+TEMP_WV+TGAS)*TEMP_ANG
  TRANS_2 = exp(TRANS_1)

  IF KEYWORD_SET(VERBOSE) THEN PRINT,'COMPUTE_TRANSMISSION: COMPUTED TRANSMISSION = ',TRANS_2
  RETURN,TRANS_2

END