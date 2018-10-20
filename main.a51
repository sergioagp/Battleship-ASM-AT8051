#include <89c51rx2.inc>
#include "battleship.inc"

EXTRN CODE (CONFIG_EX0_PS2)
EXTRN CODE (CHECK_ESC)
EXTRN CODE (CONFIG_TMR0)
EXTRN CODE (CONFIG_TMR1)
EXTRN CODE (ISRTMR1)
EXTRN CODE (CONFIG_RS232)
EXTRN CODE (SEND_RS232)

EXTRN CODE (SEND_BOARD)
EXTRN CODE (SEND_BOARDHIT)

EXTRN CODE (SEND_PB2START)
EXTRN CODE (SEND_PRESENTPLYR)	
EXTRN CODE (SENDSTRREADY)
EXTRN CODE (SEND_STRGAMEOVER)
EXTRN CODE (WAITING_DIR)
EXTRN CODE (WAITING_COORD)
EXTRN CODE (SEND_STRSHIPNR)

EXTRN CODE (WAITING_MODEINSRT)
EXTRN CODE (WAITING_MODE)

EXTRN CODE (CLEAR_BOARDS)
EXTRN CODE (ALREADY_COORD)
EXTRN CODE (HIT_MISS_COORD)

EXTRN CODE (INSERT_SHIP)
EXTRN CODE (CHECK_SHIP)

EXTRN CODE (AUTO_MOVE)
EXTRN CODE (RND_INSERT)

EXTRN CODE (CHANGE_PLAYER)

CSEG AT 0
	SJMP MAIN
CSEG AT 03H
    JMP ISR_EX0
CSEG AT 1BH
	JMP ISRTMR1
CSEG AT 33H
    ISR_EX0:
        LCALL CHECK_ESC
    RETI


	MAIN:
        MOV SP,#07           ;valor de reset 
		LCALL CONFIG_RS232
        LCALL CONFIG_TMR0       ;configurar TMR0 (modo 3) para gerar numero aleatorio inicial
        LCALL CONFIG_EX0_PS2    ;configurar PS2 que está no Pino externo 0
        LCALL CONFIG_TMR1

 
        
       

        STARTUP_PLAYERS:
        
        MOV BshipREG,#0         ;limpar flags e variaveis de bit
        MOV AUTOreg,#0          ;limpar registo de modo de jogada 8051
        LCALL CLEAR_BOARDS      ;limpar tabuleiros
        SETB P3.5               ;selecionar como entrada
        SETB EA
        
        LCALL SEND_PB2START     ;INDICA AO utilizador que
        JB P3.5,$			;espera pelo botão START seja ativado
        MOV rand8reg,TL0    ;primeiro valor para o registo do aleatorio
        LCALL WAITING_MODE
        
        MOV R1,#BOARD_1HIT      
        LCALL SEND_PRESENTPLYR      ;enviar str do presente jogador (inidcado apartir do r1)
        LCALL WAITING_MODEINSRT     ;espera que o jogador escolha se quer inserir automaticamente ou não os barcos
		MOV R1,#BOARD_1DEF        
        LCALL SEND_BOARD
        ACALL STARTUP_PLAYER        ;inserir barcos do seu jogador
        LCALL SEND_BOARD


        MOV R1,#BOARD_2HIT
        LCALL SEND_PRESENTPLYR      ;     ;enviar str do presente jogador (inidcado apartir do r1)
        JNB AUTOGAME,INSERTBRD2     ;caso for selecionado modo humano 8051 selecionar player 2 como automatico
        SETB AUTOINSRT              
        JMP SKIP_WAITING_MINSRT
        INSERTBRD2:
        LCALL WAITING_MODEINSRT     
        SKIP_WAITING_MINSRT:
        MOV R1,#BOARD_2DEF
        LCALL SEND_BOARD            ;enviar tabuleiro de defesa
        ACALL STARTUP_PLAYER
        LCALL SEND_BOARD

        CLR AUTOINSRT
        SETB TR1
        GAMELOOP:
			LCALL CHANGE_PLAYER         ;muda de jogador (presente em r1)
            JB AUTOGAME,SKIP_READY      ;caso nao for contra 8051 não perguntar se o jogador está pronto
            JB AUTOINSRT,SKIP_READY     
            LCALL SENDSTRREADY          
            JB P3.5,$			;espera pelo botão READY seja ativado
            SKIP_READY:
            LCALL SEND_PRESENTPLYR      ;ENVIAR JOGADOR A JOGAR
            MOV A,#10
            LCALL SEND_RS232

            JNB AUTOINSRT,MANUAL_PLAY
            LCALL AUTO_MOVE             ;CASO SEJA PARA JOGAR AUTOMATICAMENTE CHAMAR AUTO  JOGADA 8051
            JMP CONTINUE

        MANUAL_PLAY:                    ;INSERIR MANUALMENTE COORDENADAS PARA ATACAR
            LCALL SEND_BOARDHIT
            RECEIVE:
                LCALL WAITING_COORD     
                LCALL ALREADY_COORD		;verifica se já acertou nessa coordenada
                JB	ALRCOORD, RECEIVE	;caso sim volta a esperar nova coordenada	*/	
            ;EXECUTE_MOVE:
			LCALL HIT_MISS_COORD	;preenche no tabuleiro de ataque  
            MOV P1,#0FFH
            JNB FHIT,CONTINUE
            MOV P1,#81H     ;CASO FOR FOGO 'H.' NO DISPLAY
        CONTINUE:
			LCALL SEND_BOARDHIT         ;ENVIA NOVAMENTE TABULEIRO DE ATAQUE
            JZ  GAMEOVER                ;CASO NAO FALTE NENHUM BARCO PARA ATACAR SER GAMEOVER
            JNB AUTOGAME,GAMELOOP
            CPL AUTOINSRT               ;ALTERNAR JOGADA AUTOMATICA
            JMP	GAMELOOP

STARTUP_PLAYER:
        MOV DPTR,#TABLE_NSHIPS       
    OUTER_LOOP_INSRT:
        CLR A
        MOVC A,@A+DPTR
        JZ RET_INSERTION                 ;SAIDA do loop, quando atingir o valor 0 (break table)
        MOV SHIP_NUMBER,A               ;inicializar o primeiro tipo de barco  
        JB AUTOINSRT,INNER_LOOP_INSRT   ;CASO for para inserir automaticamente nem mostrar que barco é para inserir
		LCALL SEND_STRSHIPNR
    INNER_LOOP_INSRT:
        JNB AUTOINSRT,MANUALINSERT      ;saltar caso seja para inserir manualmente
        ;AUTOINSERT:
        LCALL   RND_INSERT              ;inserir o barco em modo random
        JMP CHECK_VLDSHIP

        MANUALINSERT:
        MOV A,SHIP_NUMBER
        DEC A
        JZ  SKIP_DIR
        LCALL WAITING_DIR               ;pedir a direção (horizontal ou vertical) de inserçao ao  utilizador 
        SKIP_DIR:
        LCALL WAITING_COORD             ;pedir coordenada

    CHECK_VLDSHIP:                      ;verificar se pode colocar esse barco nessas direções
        LCALL CHECK_SHIP
        JNB VALID_SHIP,INNER_LOOP_INSRT    ;caso a sua incerção não seja valida voltar a pedir dir, e coord
        LCALL INSERT_SHIP                   ;insere o barco tal como pediu
        JB AUTOINSRT,SKIP_SEND              ;enviar tabuleiro caso tenha sido inserção manual
        LCALL SEND_BOARD
    SKIP_SEND:
        INC DPTR
        JMP OUTER_LOOP_INSRT
     RET_INSERTION:  
        RET

GAMEOVER:
    CLR TR1
    LCALL SEND_STRGAMEOVER                  ;ENVIAR A INDICAÇÃO DE QUEM GANHOU E VOLTAR AO INICIO
    JMP STARTUP_PLAYERS


TABLE_NSHIPS:
    DB 4
    DB 3
    DB 2
    DB 2
    DB 1
    DB 1
    DB 1
    DB 0        ;BREAK

END