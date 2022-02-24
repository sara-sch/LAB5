PROCESSOR 16F887

; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>

RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
  
PSECT udata_shr			 ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    valor:		DS 1	; Contiene valor a mostrar en los displays de 7-seg
    banderas:		DS 1	; Indica que display hay que encender
    nibbles:		DS 2	; Contiene los nibbles alto y bajo de valor
    display:		DS 2	; Representación de cada nibble en el display de 7-seg

PSECT resVect, class = CODE, abs, delta = 2
; ----------- VECTOR RESET ----------------

ORG 00h
resVect:
	PAGESEL main	    ; cambio de pagina
	GOTO main

PSECT intVect, class=CODE, abs, delta=2
;---------------------interrupt vector---------------------
ORG 04h
PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS

ISR:
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_IOCB		; Si -> Subrutina de interrupción de PORTB
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0

POP:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

;----------------subrutinas int---------------------    
INT_IOCB:
    BANKSEL PORTA
    BTFSS   PORTB, 0	    ; Primer botón
    INCF    valor	    ; Incremento de contador
    BTFSS   PORTB, 1	    ; Segundo botón
    DECF    valor	    ; Decremento de contador
    BCF	    RBIF	    ; Se limpia bandera de interrupción de PORTB
    RETURN
    
INT_TMR0:
    RESET_TMR0 217		; Reiniciamos TMR0 para 50ms
    CALL    MOSTRAR_VALOR	; Mostramos valor en hexadecimal en los displays
    RETURN


PSECT code, delta = 2, abs
; ----------- CONFIGURATION ---------------
ORG 100h
main:
    CALL CONFIG_IO		; Configuraciones para que el programa funcione correctamente
    CALL CONFIG_RELOJ
    CALL CONFIG_IOCB
    CALL CONFIG_INT
    CALL CONFIG_TMR0		; Configuración de TMR0
    BANKSEL PORTA

LOOP:
    ;MOVF    PORTA, W		; Valor del PORTA a W
    MOVF    valor, W		; Movemos W a variable valor
    CALL    OBTENER_NIBBLE	; Guardamos nibble alto y bajo de valor
    CALL    SET_DISPLAY		; Guardamos los valores a enviar en PORTA para mostrar valor en hex
    GOTO    LOOP

; ------------subrutinas

CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH		; I/O digitales

    BANKSEL TRISA
    BSF	    TRISB, 0		; PORTB0 como entrada
    BSF	    TRISB, 1		; PORTB1 como entrada
    CLRF    TRISA		; PORTA como salida
    BCF	    TRISD, 0		; RD0 como salida / display nibble alto
    BCF	    TRISD, 1		; RD1 como salida / display nibble bajo

    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7

    BANKSEL WPUB
    BSF	    WPUB, 0
    BSF	    WPUB, 1

    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTD
    CLRF    banderas
    RETURN

CONFIG_RELOJ:
    BANKSEL OSCCON	;cambiamos a banco 1
    BSF OSCCON, 0	; scs -> 1, usamos reloj interno
    BSF OSCCON, 6
    BSF OSCCON, 5
    BCF OSCCON, 4	; IRCF<2:0> -> 110 4MHz
    RETURN
    
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0			; PS<2:0> -> 111 prescaler 1 : 256
    RESET_TMR0 217		; Reiniciamos TMR0 para 10ms
    RETURN 

CONFIG_INT:
    BANKSEL INTCON
    BSF GIE		; Habilitamos interrupciones
    BSF RBIE		; Habilitamos interrupcion RBIE
    BSF	T0IE		; Habilitamos interrupcion TMR0
    BCF	T0IF		; Limpiamos bandera de int. de TMR0
    BCF RBIF		; Limpia bandera RBIF
    RETURN

CONFIG_IOCB:
    BANKSEL TRISA
    BSF	    IOCB, 0	; Interrupción habilitada en PORTB0
    BSF	    IOCB, 1	; Interrupción habilitada en PORTB1

    BANKSEL PORTB
    MOVF    PORTB, W	; Al leer, deja de hacer mismatch
    BCF	    RBIF	; Limpiamos bandera de interrupción
    RETURN
    
OBTENER_NIBBLE:			; Obtenemos nibble bajo
    MOVLW   0x0F		;    Valor = 1101 0101
    ANDWF   valor, W		;	 AND 0000 1111
    MOVWF   nibbles		;	     0000 0101	
				; Obtenemos nibble alto
    MOVLW   0xF0		;     Valor = 1101 0101
    ANDWF   valor, W		;	  AND 1111 0000
    MOVWF   nibbles+1		;	      1101 0000
    SWAPF   nibbles+1, F	;	      0000 1101	
    RETURN

SET_DISPLAY:
    MOVF    nibbles, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTA
    MOVWF   display		; Guardamos en display
    
    MOVF    nibbles+1, W	; Movemos nibble alto a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTA
    MOVWF   display+1		; Guardamos en display+1
    RETURN
    
MOSTRAR_VALOR:
    BCF	    PORTD, 0		; Apagamos display de nibble alto
    BCF	    PORTD, 1		; Apagamos display de nibble bajo
    BTFSC   banderas, 0		; Verificamos bandera
    GOTO    DISPLAY_1		
    
    DISPLAY_0:			
	MOVF    display, W	; Movemos display a W
	MOVWF   PORTA		; Movemos Valor de tabla a PORTA
	BSF	PORTD, 1	; Encendemos display de nibble bajo
	BSF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

    DISPLAY_1:
	MOVF    display+1, W	; Movemos display+1 a W
	MOVWF   PORTA		; Movemos Valor de tabla a PORTA
	BSF	PORTD, 0	; Encendemos display de nibble alto
	BCF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

    
ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F
    
END


