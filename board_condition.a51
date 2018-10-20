#include <89c51rx2.inc>
#include "battleship.inc"

NAME BOARDCONDITION

PUBLIC ALREADY_COORD
PUBLIC HIT_MISS_COORD	
PUBLIC INSERT_SHIP
PUBLIC CHECK_SHIP



BOARDCONDITION SEGMENT CODE
RSEG BOARDCONDITION

;/**
; * FUNCTION_PURPOSE:Inserir o barco.
; * FUNCTION_INPUTS:R1-Tabuleiro de inserção, SHIP_NUMBER
; * FUNCTION_OUTPUTS:R1-Tabuleiro de inserção
; */
INSERT_SHIP:
    PUSH AR1
    MOV A,R1
    ADD A,POSY					;ADICIONA AO A O VALOR DA LINHA, (80H + LINHA)
	MOV R1,A					;GUARDO NO R1 ESSA LINHA
	MOV R5,SHIP_NUMBER			;GUARDO NO R5 O NUMERO DO BARCO
	JB SHIP_ORI,INSERT_VERTI	;VERIFICO SE É VERTICAL. SE SHIP_ORI==1, INSERE BARCO VERTICAL. SE SHIP_ORI==0, INSERE BARCO HORIZONTAL
	MOV R7,POSX					;*****INSERCAO HORIZONTAL**** GUARDA EM R7 O VALOR DA COLUNA PARA USAR NA MASCARA DINAMICA
	MOV R6,SHIP_NUMBER			;GUARDA EM R6 O NUMERO DO BARCO PARA USAR NA MASCARA DINAMICA
	CALL CREATE_MASK			;CRIA MASCARA DINANMICA
	ORL A,@R1					;COLOCA O RESPECTIVO BIT A 1
	MOV @R1,A					;MOVE PARA A RESPECTIVA LINHA O VALOR

	POP AR1                     ;RETORNA TABULEIRO ALTERADO(primeira linha)
    RET
	
INSERT_VERTI:					;*****INSERCAO VERTICAL*****
	LCALL LOCATE_XCOORD			;CHAMO A FUNCAO LOCATE_XCOORD PORQUE SO QUERO ALTERAR UM BIT NUMA LINHA
	ORL A,@R1					;COLOCO O BIT A 1
	MOV @R1,A					;MOVO PARA A RESPECTIVA LINHA
	INC R1						;INCREMENTE A LINHA
	DJNZ R5,INSERT_VERTI		;DECREMENTE O NUMERO DE VEZES DO TAMANHO DO BARCO
    
    POP AR1                     ;RETORNA TABULEIRO ALTERADO(primeira linha)
    RET
	
;/**
; * FUNCTION_PURPOSE:Verificar e preparar R1,R4 (Y).
; * FUNCTION_INPUTS:R2-MASCARA, R1-tabuleiro para verificar colocação,R4 quantas inc Y R7-X0,R6-quantas inc ao X
; * FUNCTION_OUTPUTS:VALID_SHIP,R1
; */
CHECK_SHIP:
    PUSH AR1							;indice do jogador presente
	MOV R7,POSX
	JNB SHIP_ORI,HORIZONTAL_CHECK		;se SHIP_ORI==0 verifica-se entao as condições horizontais, senao verificam-se as condicoes verticais
;VERTICAL_CHECK:
	MOV R4,SHIP_NUMBER					;prepara r4(numero x que vai pecorrer no eixo Y com o numero do barco
	
	;preparar a nivel do eixo Y(R1,R4)
	MOV A,POSY							;inputs da função STATUS_LIMIT
	MOV R3,AR4
	LCALL STATUS_LIMIT
	JNB VLD_LMT,INVALID_SHIP			;caso fora os limites
	MOV A, R1							;outputs da função, 
	ADD A,R2							;indice do jogador presente + POSY
	MOV R1,A
	MOV R4,AR3
	
	;preparar a nivel do eixo X (R7,R6)
	MOV A,POSX							;imputs da função STATUS_LIMIT
	MOV R3,#1
	LCALL STATUS_LIMIT
	JNB VLD_LMT,INVALID_SHIP
	MOV R7,AR2							;outputs da função
	MOV R6,AR3
	
	JMP CHECKING_SHIP

HORIZONTAL_CHECK:
	MOV R6,SHIP_NUMBER					;prepara o n_vezes do X percorrer o barco a nivel do eixo X 
	
	;preparar a nivel do eixo Y
	MOV A,POSY
	MOV R3,#1
	LCALL STATUS_LIMIT
	JNB VLD_LMT,INVALID_SHIP
	MOV A, R1
	ADD A,R2
	MOV R1,A
	MOV R4,AR3
	
	;preparar a nivel do eixo dos X
	MOV A,POSX
	MOV R3,AR6
	LCALL STATUS_LIMIT
	JNB VLD_LMT,INVALID_SHIP
	MOV R7,AR2
	MOV R6,AR3
;/**
; * FUNCTION_PURPOSE:Verificar se é possivel colocar o barco assumindo que está nos limites.
; * FUNCTION_INPUTS:R2-MASCARA R1-Y0,R4 quantas inc Y R7-X0,R6-quantas inc ao X
; * FUNCTION_OUTPUTS:VALID_SHIP
; */
CHECKING_SHIP:
;CREATE_SHIPMASK:
	INC R4					;fará no minimo numero do barco/vizinhança +1 casa
	INC R6
	ACALL CREATE_MASK		;cria mascara
	MOV R2,A
LOOP_CHECKING:
	MOV A,R2					;o acumulador fica com a máscara
	ANL A,@R1					;caso algo dos valores da var. posx estiver a 1-> inválida colocação
	JNZ INVALID_SHIP				
	INC R1						
	DJNZ R4,LOOP_CHECKING		
	SETB VALID_SHIP				

    POP AR1                     ;RETORNA TABULEIRO ALTERADO(primeira linha)
    RET

INVALID_SHIP:
	CLR VALID_SHIP
    
    POP AR1                     ;RETORNA TABULEIRO ALTERADO(primeira linha)
	RET
;/**
; * FUNCTION_PURPOSE:Verificar e converter coordenadas de forma a verificar a colocação do barco.
; * FUNCTION_INPUTS:ACC com POS_X/Y,R3-quantos inc são precisos no minimo
; * FUNCTION_OUTPUTS:R2-X_Yinicial,R3-quantos inc ao XouY serão feitos VALD_LMIT
; */

STATUS_LIMIT:
	MOV R2,A			;verificar se está na borda de localização
	JZ SKIP_INCR		
	DEC R2				;caso não: começar a verificação a R2--
	ADD A,R3			;verificar no outro limite e se não a ultrapassa
	CLR C
	SUBB A,#8
	JZ SKIP_INCR		;caso ficar na borda
    JNC	INVALID_LIMIT	;caso ultrapassar
	INC R3				;caso não estiver em nenhuma borda executar  vezes  
SKIP_INCR:	
	SETB VLD_LMT		;dentro do limite
	RET
INVALID_LIMIT:
	CLR VLD_LMT			;fora dos limites
	RET

;/**
; * FUNCTION_PURPOSE:cria mascara para que seja possivel ir a POSX sem alterar valores vizinhos.
; * FUNCTION_INPUTS:ACC-BOARD,POSX, R6-numero de 1s, R7 POSIÇÃO MAIS A ESQUERDA
; * FUNCTION_OUTPUTS:ACC-MASCARA
; */
LOCATE_XCOORD:
	MOV R7,POSX
	MOV R6,#1
	CREATE_MASK:	
		CLR A						;limpo o acumulador para nao utilizar lixo ao rodar
		LOOP_N1s:	
			SETB C						;Carry precisa de ficar a 1 porque vou rodar o acumulador com o carry
			RRC A
			DJNZ R6,LOOP_N1s
		;R7 fica com o numero de vezes que pretendo shiftar o byte à esquerda
		CJNE R7,#0,LOOP_TO_INVERT
		JMP RET_CREATE
		LOOP_TO_INVERT:
			RR A					;dependendo do valor de POSX, o Acumulador ficara com o valor de 2^POSX
			DJNZ R7,LOOP_TO_INVERT
	RET_CREATE:
	RET							;da linha da matriz eu faço esta instrucao
;/**
; * FUNCTION_PURPOSE:	Verificar se certa posição já foi atacada
; * FUNCTION_INPUTS:R1-BOARD,POSX,POSY
; * FUNCTION_OUTPUTS:ACC-MASCARA,R1
; */
ALREADY_COORD:
    PUSH AR1
	MOV A,R1					;vai buscar o endereço da primeira linha da matriz DE ATAQUE para o acumulador
	ADD A,POSY					;adiciona à primeira linha a var POSY (0-7) para descobrir qual linha trabalhar
	MOV R1,A					;guarda o endereço da linha da matriz no R1
	ACALL LOCATE_XCOORD
	ANL A,@R1
	JNZ EXISTCOORD
	CLR ALRCOORD

    POP AR1                     ;RETORNA TABULEIRO ALTERADO(primeira linha)
    RET
EXISTCOORD:
	SETB ALRCOORD
	POP AR1                     ;RETORNA TABULEIRO ALTERADO(primeira linha)
    RET
	
;/**
; * FUNCTION_PURPOSE:ativa bit da coord no tabuleiro de ATAQUE.
; * FUNCTION_INPUTS:R0(DEFESA),R1(ATAQUE)
; * FUNCTION_OUTPUTS:FHIT,BOARD ATAQUE
; */
HIT_MISS_COORD:
    PUSH AR1

	MOV A,R1			    	;vai buscar o endereço da primeira linha da matriz DE ATAQUE para o acumulador
	ADD A,POSY					;adiciona à primeira linha a var POSY (0-7) para descobrir qual linha trabalhar
	MOV R1,A					;guarda o endereço da linha da matriz no R0
	ADD A,#10H					;salta por cima de um tabuleiro para atingir o tabuleiro de DEFESA do oponente
	MOV R0,A					;guarda o endereço da linha da matriz no R0

	ACALL LOCATE_XCOORD			;CRIA MASCARA PARA LOCALIZAR
	
	PUSH ACC					;guardou a MASCARA
	ORL A,@R1					;ativa bit no tabuleiro de ATAQUE
	MOV @R1,A
	POP ACC						;verifica se foi hit ou miss
	ANL A,@R0					;Verifica que bit se localiza na POSY POSX da primeira matriz
	JNZ HIT_COORD				;CASO estiver a 1 significa que se localiza barco (HIT)
	CLR FHIT					;miss

	POP AR1
    RET

HIT_COORD:
	;XRL A,@R0					;XOR para inverter o bit que escolhi atraves das coordenadas no tabuleiro de DEFESA
	;MOV @R0,A
	SETB FHIT

	POP AR1
    RET

END