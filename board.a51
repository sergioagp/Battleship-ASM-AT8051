#include <89c51rx2.inc>
#include "battleship.inc"

NAME BOARD
	
PUBLIC SEND_BOARD
PUBLIC SEND_BOARDHIT
PUBLIC RECEIVE_COORD
PUBLIC CLEAR_BOARDS
PUBLIC RECEIVE_DIR
PUBLIC CHANGE_PLAYER
PUBLIC CHECK_COORD

EXTRN CODE (SEND_RS232)
EXTRN CODE (RECEIVE_PS2)

BOARD SEGMENT CODE
RSEG BOARD

;/**
; * FUNCTION_PURPOSE:CONDIÇÃO:verifica e converte (0-7) se a coordenada INPUT está dentro dos limites, intervalo dos limites 8
; * FUNCTION_INPUTS:ACC-parametro para verificar
; * FUNCTION_OUTPUTS:ACC-parametro convertido, VALID_COORD
; */		
CHECK_COORD:
	CLR C
	SUBB A,COD_ASCII
	JC ERRO_COORD			;detetar limite inferior em numero e letra
    CJNE A,#8,$+3
	JNC ERRO_COORD
	SETB VALID_COORD
	RET
ERRO_COORD:
	CLR VALID_COORD
	RET

SEND_BOARD:					;ele primeiro vai ao LSBYTE e vai ao MSBIT na posição A1
	PUSH AR1
    MOV A,#10;'\n'
	CALL SEND_RS232
    CALL WRITE_COORD
	MOV R5,#'A' 			;para escrever as coordenadas Y, começo em A
	MOV R7,#8 				;8loops para percorrer as 8 linhas da matriz
	MOV R6,#8 				;8loops para percorrer os 8 bits duma linha da matriz(que é um byte)
	OUTER_LOOP:
		MOV A,R5
		CALL SEND_RS232 	;escreve as coordenadas A-H 
		MOV A,#' '
		CALL SEND_RS232
		CALL SEND_RS232 	;dois espaços para melhorar interface
		MOV A,@R1 			;acumulador fica com o valor de uma linha da matriz
		INNER_LOOP:
			RLC A 			;passo para o carry o MSB
			PUSH ACC 		;guardo o valor do acumulador pois a seguir vou ter que limpar
			CLR A 			;limpo o acumulador 
			ADDC A,#30H 	; Apos o CLR A, basicamente esta instrucao é A = 30H+0/1 (carry)
			CALL SEND_RS232 ;envia 30H ou 31H dependendo do caso (0 ou 1)
			MOV A,#' ' 
			CALL SEND_RS232 ;para dar espaçamento entre os elementos da matriz
			POP ACC 		;recuperar o valor do acumulador
			DJNZ R6,INNER_LOOP
		MOV A,#10 			;NL = New Line
		CALL SEND_RS232
		MOV R6,#8 			;reestabelece o numero de loops
		INC R1 				;passa para o byte seguinte/passa para a linha seguinte da matriz
		INC R5 				;incrementa as coordenadas Y
		DJNZ R7,OUTER_LOOP
		MOV A,#10 			;NL = New Line
		CALL SEND_RS232
		CALL SEND_RS232
	POP AR1
    RET

;/**
; * FUNCTION_PURPOSE: Transmitir por via porta série o tabuleiro
; * FUNCTION_INPUTS:R1(HIT),R0(DEFENSE)
; * FUNCTION_OUTPUTS:void
; */	
SEND_BOARDHIT:					;ele primeiro vai ao LSBYTE e vai ao MSBIT na posição A1	
	PUSH AR1
    MOV A,#10;'\n'
	CALL SEND_RS232
    CALL WRITE_COORD
	MOV R5,#'A' 			;para escrever as coordenadas Y, começo em A
	MOV R7,#8 				;8loops para percorrer as 8 linhas da matriz
	MOV R6,#8 				;8loops para percorrer os 8 bits duma linha da matriz(que é um byte)
    MOV R4,#14               ;contador de barcos atingidos

    MOV A,R1
    ADD A,#10H
    MOV R0,A
	HITOUTER_LOOP:
		MOV A,R5
		CALL SEND_RS232 	;escreve as coordenadas A-H 
		MOV A,#' '
		CALL SEND_RS232
		CALL SEND_RS232 	;dois espaços para melhorar interface
        
		MOV A,@R1 			;acumulador fica com o valor de uma linha da matriz
		MOV A,#80H
        HITINNER_LOOP:
            PUSH ACC
            LCALL WRITE_PIECE
			CALL SEND_RS232 
			MOV A,#' ' 
			CALL SEND_RS232 ;para dar espaçamento entre os elementos da matriz
			POP ACC 		;recuperar o valor do acumulador
            RR A
			DJNZ R6,HITINNER_LOOP
		MOV A,#10 			;NL = New Line
		CALL SEND_RS232
		MOV R6,#8 			;reestabelece o numero de loops
		INC R1 				;passa para o byte seguinte/passa para a linha seguinte da matriz
        INC R0
		INC R5 				;incrementa as coordenadas Y
		DJNZ R7,HITOUTER_LOOP
		MOV A,#10 			;NL = New Line
		CALL SEND_RS232
		CALL SEND_RS232
    MOV A,R4
	POP AR1
    RET

WRITE_COORD:
	MOV A,#' '
	CALL SEND_RS232
	CALL SEND_RS232
	CALL SEND_RS232 		; 3 espacos iniciais para ficar corretamente posicionado
	MOV A,#'1'
	LOOP_COORD:
		CALL SEND_RS232 	;imprime as coordenadas X
		PUSH ACC 			;guardo na stack o valor atual de A pois preciso de enviar espaços para o terminal
		MOV A,#' ' 
		CALL SEND_RS232 	;envio um espaço para o terminal
		POP ACC 			;recupero o valor do acumulador
		INC A 				;passo para a coordenada X seguinte (se era 1 passa agora para 2, etc)
		CJNE A,#'9',LOOP_COORD ;quando atingir o numero 9 acaba o ciclo
	MOV A,#10;'\n'
	CALL SEND_RS232
	CALL SEND_RS232 		;2 enters para melhorar a percecao do posicionamento
	RET

WRITE_PIECE:
    ANL A,@R1               ;verifica que elemento está no tabuleiro de ataque
    JZ EMPTY_PIECE          ;caso esteja a zero então envia '0'
    ANL A,@R0               ;caso esteja a 1 verificar com o tabuleiro de defesa do oponente se este está também a q
    JZ MISS_PIECE           ;caso não envia simplesmente 1
    MOV A,#'2'              ;caso sim significa que foi HIT e envia '2'
    DEC R4                  ;e sendo assim menos um barco para atingir
    RET
EMPTY_PIECE:
    MOV A,#'0'
    RET
MISS_PIECE:
    MOV A,#'1'
    RET


;/**
; * FUNCTION_PURPOSE: Zera os Boards (4*8bytes apartir)
; * FUNCTION_INPUTS:VOID
; * FUNCTION_OUTPUTS:R3,R7,BOARD
; */
CLEAR_BOARDS:
	MOV R7,#32              ;(8+8+8+8 2PLAYERS, 4 boards, 8 bytes each)
	MOV R3,SP
	MOV SP,#BOARDS-1
	CLR A
	CLR_LOOP:
		PUSH ACC
		DJNZ R7,CLR_LOOP
	MOV SP,R3
	RET


RECEIVE_COORD:
    LCALL RECEIVE_PS2
	;JB VALID_COORD,NUMBERCOORD				;verifica se já recebeu letra valida
	MOV COD_ASCII,#'A'						;caso nao: prepara valor de limite para letra
	
	LCALL CHECK_COORD			
	JNB VALID_COORD,RECEIVE_COORD			;caso não: for valida coordenada salta para o inicio da rotina
	;CLR VALID_COORD	
    MOV POSY,A								;armazena
NUMBERCOORD:
    LCALL RECEIVE_PS2
	MOV COD_ASCII,#'1'						;prepara valor de limite para o numero				
	LCALL CHECK_COORD
	JNB VALID_COORD,NUMBERCOORD 				;caso não: for valida coordenada salta para rotina de erro
	MOV POSX,A
    ;SETB FCOORD								;ativa FLAG de receção da coordenada
	RET

ERRCOORD:
	;CLR FCOORD
	RET

RECEIVE_DIR:
	LCALL RECEIVE_PS2                       ;recebe tecla pressionar
	CJNE A,#'V',OTHER_DIR                      ;caso seja 'V' ou 'H' então significa que obteve direção valida
	SETB SHIP_ORI           
	JMP DIR_END
	OTHER_DIR:
		CJNE A,#'H',RECEIVE_DIR                 ;se não volta a pedir
		CLR SHIP_ORI
	DIR_END:
	RET

;/**
; * FUNCTION_PURPOSE: Muda de jogador e caso não exista, por definição coloca no jogador1
; * FUNCTION_INPUTS:R0,R1
; * FUNCTION_OUTPUTS:R0,R1
; */
CHANGE_PLAYER:
	CJNE R1,#BOARD_1HIT,CHANGE2P1
;CHANGE2P2:	
	MOV	R1,#BOARD_2HIT             ;e registará no seu tabuleiro de ataque 
	RET
CHANGE2P1:
	MOV R1,#BOARD_1HIT             ;e registará no seu tabuleiro de ataque 
	RET
	
END