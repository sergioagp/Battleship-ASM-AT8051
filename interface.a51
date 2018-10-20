#include <89c51rx2.inc>
#include "battleship.inc"

NAME INTERFACE

PUBLIC CONFIG_TMR0
PUBLIC CHECK_ESC
PUBLIC CONFIG_EX0_PS2

PUBLIC CONFIG_TMR1
PUBLIC CONFIG_RS232
PUBLIC SEND_RS232
PUBLIC RECEIVE_PS2
PUBLIC ISRTMR1
PUBLIC WAITING_MODEINSRT
PUBLIC WAITING_MODE

EXTRN CODE (SENDSTRMODE)
EXTRN CODE (SENDMODEINSRT)

INTERFACECODE SEGMENT CODE
RSEG INTERFACECODE

SCLK  	EQU		P3.2
SDATA	EQU		P3.4

CONFIG_TMR0:
    ANL TMOD,#0F0h				;Timer 0 mode 2 with software gate
	ORL TMOD,#02h				;GATE0=0; C/T0'=1; M10=1; M00=0;
	MOV TH0,#0					;init values
	MOV TL0,#0;		
    SETB TR0
	RET
	
CONFIG_TMR1:
	MOV SEGUNDO,#0
	MOV MINUTO,#0
	MOV LOOPS1SEC,#100
	ORL TMOD,#10H
	MOV TH1,#HIGH(-10000)
	MOV TL1,#LOW(-10000)
	SETB ET1
	RET
ISRTMR1:
	MOV TL1,#LOW(-10000)		;reload do timer
    MOV TH1,#HIGH(-10000)		;reload do timer
	PUSH PSW					;proposito disto é principalmente guardar o valor do CARRY
	DEC LOOPS1SEC
	PUSH ACC
	MOV A,LOOPS1SEC
	JZ INCSEGUNDO
	POP ACC
	POP PSW						;recupero o valor do CARRY
	RETI
	INCSEGUNDO:
		MOV LOOPS1SEC,#100
		INC SEGUNDO
		MOV A,SEGUNDO
		CLR C
		CJNE A,#60,$+3			;verifica se os segundos são menores do que 60
		JNC INCMINUTO
		POP ACC
		POP PSW
		RETI
		INCMINUTO:
			MOV SEGUNDO,#0
			INC MINUTO
			POP ACC
			POP PSW
			RETI
CONFIG_RS232:
	ORL PCON,#80H               ;CONFIGURAR COMUNICAÇÃO PELA PORTA SÉRIE, dobra o baud rate
	MOV BDRCON,#1EH             ;configura o BDR interno como generator 
	MOV BRL,#217                ;BAUDRATE 9600
	MOV SCON,#60H

	RET
CONFIG_EX0_PS2:
    SETB SCLK							;SELECIONA OS PINOS USADOS PELO PS2 COMO ENTRADAS
    SETB SDATA							; 

    CLR IT0                             ;opera por nível e a 0
    SETB P3.2
    SETB EX0                            ;ATIVA INTERRUPÇÃO EXTERNA (DO CLOCK
    RET

CHECK_ESC:
    CLR EX0                             ;DESATIVA
    JB SDATA,NOT_ESC					;start bit invalido
    JNB SCLK,$
    ACALL READBYTE                      ;Lê um byte
    LOOPb:
		ACALL RECEIVE_11BITS            ;recebe outro
		CJNE A,#0F0H,LOOPb              ;verifica se foi solto
	ACALL RECEIVE_11BITS                ;le novamente

    CJNE A,#76H,NOT_ESC         ;caso for pressionada ESC
    POP ACC
    POP ACC                     ;retirar valor de retorno da função
    POP ACC                     
    POP ACC                     ;sair da interrupção e fazer RESET
    CLR A
    PUSH ACC                    ;retirando os valores armazenados do LCALL e substituido por 00
    PUSH ACC
    RETI						;fecha a interrupçao e salta para reset
    NOT_ESC:
    SETB EX0
    RET
    
WAITING_MODE:
	LCALL SENDSTRMODE                           ;selecionar modo de jogo
		RCV_MODE:
			ACALL RECEIVE_PS2                   ;receber pelo ps2 tecla precionada
			CJNE A,#'1',CHECK_2                 ;caso for '1' ou '2' seleciona as configurações do modo respetivo
			CLR AUTOGAME
            MOV A,#10
            LCALL SEND_RS232
            RET
			CHECK_2:
				CJNE A,#'2',RCV_MODE            ;se não volta a esperar por um '1' ou '2'
				SETB AUTOGAME
                MOV A,#10
                LCALL SEND_RS232
				RET
WAITING_MODEINSRT:
    LCALL SENDMODEINSRT                         ;pedir ao utlizador se pretende inserir automaricamente (Y) ou não (N)
		RCV_INSRT:
			ACALL RECEIVE_PS2
			CJNE A,#'Y',CHECK_N             ;
            SETB AUTOINSRT
            MOV A,#10
            LCALL SEND_RS232
            RET
			CHECK_N:
				CJNE A,#'N',RCV_INSRT
				CLR AUTOINSRT
                MOV A,#10					;new line
                LCALL SEND_RS232
				RET

SEND_RS232:
	JB TI,$
	MOV SBUF,A
   	JNB TI,$
	CLR TI
	RET
	
RECEIVE_PS2:
	SETB SCLK							;clock começa a 1
    SETB SDATA							;leitura do valor do pino P2.1 
    CLR EX0							;desativar a interrupção provocada pelo clock
	PUSH DPL
	PUSH DPH
	LOOP:
		ACALL RECEIVE_11BITS
		CJNE A,#0F0H,LOOP
	ACALL RECEIVE_11BITS
    CJNE A,#76H,NOT_KEYESC         ;caso for pressionada ESC
    JMP 00H
   NOT_KEYESC:
	MOV R2,A                    	;guardar num registo para que se possa utilizar o acumulador para procurar tecla
	MOV DPTR, #TABLE_PS2
	ACALL FINDKEY
	ACALL SEND_RS232

	POP DPH
	POP DPL
    SETB EX0
	RET
    
	RECEIVE_11BITS:
	ACALL READ_BIT						;esperar pelo start bit
	READBYTE:							;le byte
		MOV R7,#8						;Byte = 8 bits			
		CLR A
		RBLOOP:	
			JB SCLK,$ 					;esperar que a linha de relógio venha a zero, está a zero => ler bit
			MOV C,SDATA 				;ler de P2.1 para o carry
			RRC A
			JNB SCLK,$					;esperar que o relógio volte a nível alto para poder ler bit seguinte
		DJNZ R7,RBLOOP					;esperar que a linha de relógio volte para um	
	ACALL READ_BIT						;espera pelo bit de paridade
	READ_BIT:							;espera pelo stop bit
		JB SCLK,$
		JNB SCLK,$
	RET

FINDKEY:
	CLR A                               
	MOVC A,@A+DPTR                      ;procura na tabela escrita na memoria de codigo pelo codigo igual
	JZ RECEIVE_END                      ;caso encontrar 0 significa que chegou ao fim da tabela
	XRL A,R2                            ;no r2 é que está contido a tecla a procura, caso forem iguais com o Xorl invertem e ficam a 0
	JZ FOUNDKEY
	INC DPTR                            ;salta duas vezes para que não apanhe a correspondencia em codigo ASCII da tecla pressionada
	INC DPTR
	JMP FINDKEY

RECEIVE_END:
	RET
	
FOUNDKEY:
	INC DPTR                            ;caso encontrou, incremanta para a converter em codigo ascii (já presente na tabela)
	CLR A
	MOVC A,@A+DPTR
	RET


TABLE_PS2:
	//tabela com todas as letras
	DB 01Ch,'A'
	DB 032h,'B'
	DB 021h,'C'
	DB 023h,'D'
	DB 024h,'E'
	DB 02Bh,'F'
	DB 034h,'G'
	DB 033h,'H'
	DB 043h,'I'
	DB 03Bh,'J'
	DB 042h,'K'
	DB 04Bh,'L'
	DB 03Ah,'M'
	DB 031h,'N'
	DB 044h,'O'
	DB 04Dh,'P'
	DB 015h,'Q'
	DB 02Dh,'R'
	DB 01Bh,'S'
	DB 02Ch,'T'
	DB 03Ch,'U'
	DB 02Ah,'V'
	DB 01Dh,'W'
	DB 022h,'X'
	DB 035h,'Y'
	DB 01Ah,'Z'
	
	//tabela com todos os numeros
	DB 045h,'0'
	DB 016h,'1'
	DB 01Eh,'2'
	DB 026h,'3'
	DB 025h,'4'
	DB 02Eh,'5'
	DB 036h,'6'
	DB 03Dh,'7'
	DB 03Eh,'8'
	DB 046h,'9'	

	DB 0		;break
END