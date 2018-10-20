#include <89c51rx2.inc>
#include "battleship.inc"

NAME AUTOPLAY

PUBLIC AUTO_MOVE
PUBLIC RND_INSERT

EXTRN CODE (CHECK_SHIP)
EXTRN CODE (INSERT_SHIP)
EXTRN CODE (CHECK_COORD)
EXTRN CODE (ALREADY_COORD)
EXTRN CODE (HIT_MISS_COORD)

AUTOPLAY SEGMENT CODE
RSEG AUTOPLAY

;generates an 8 bit pseudo-random number which is returned in Acc.
;one byte of memory must be available for rand8reg

RAND8:									;https://www.pjrc.com/tech/8051/rand.html
    MOV	A, Rand8reg
	JNZ	RAND8b
	CPL	A               ;A=FF
	MOV	Rand8reg, A     ;Rand8reg=FF
rand8b:
    ANL	A, /* TL0*/#10111000b   ;operação para modificar bit de paridade do numero de 1s presente nas 4localizaçoes indicadas
	MOV	C, P                    ;passa para o carry para depois o acumluador ser rodado com o mesmo
	MOV	A, Rand8reg
	RLC	A                   ;roda com o bit de paridade
	MOV	Rand8reg, A         ;prepara prox com o seu valor aleatorio
	RET

RND_COORD:
	MOV POSY,#0   ;COORDY
    ;MOV POSX,#0   ;COORDX
    LCALL RAND8
    CLR C
    RRC A
    CLR C
    RRC A           ;A a dividir por 4(255->64
    PUSH ACC
    ANL A,#07H			;obter os 3 bits menos significativos
    MOV POSX,A        ;ARMAZENAR NA COORDX O VALOR OBTIDO
    POP ACC
    SWAP A          ;trocar nibble para obter coordY
    JNB ACC.7,SKIP_INCY ;caso esteja acima de 7, significa que precisa de incrementar 1 linha
    INC POSY
SKIP_INCY:
    ANL A,#0FH          ;obtem nibble inferior
    RL A                ;multiplica por 2
    ADD A,POSY            ;e addicona +1 caso o nible superior fosse maior que 7
    MOV POSY,A            ;armazena na coordY
    RET


RND_INSERT:
        ACALL RAND8
        RRC   A
        MOV   SHIP_ORI,C                   ;Orientação aletória, 0-h,1-v
		ACALL RND_COORD                  ;Coordaleatoria		
        RET

AUTO_MOVE:
    MOV A,AUTOreg
    ANL A,#03
    SWITCH_ACC:
        MOV DPTR,#CASEJUMP
        RL A
        JMP @A+DPTR
    CASEJUMP:
    AJMP RND_VLDPLAY
    AJMP FIND_DIR
    AJMP FIND_1LIMIT
    AJMP FIND_2LIMIT
RND_VLDPLAY:
    ANL AUTOREG,#0F0H
    ACALL RND_COORD
    LCALL ALREADY_COORD		;verifica se já acertou nessa coordenada
	JB	ALRCOORD,RND_VLDPLAY 	;caso sim volta a esperar nova coordenada
    MOV LPOSX,POSX
    MOV LPOSY,POSY
    MOV IPOSX,POSX
    MOV IPOSY,POSY
    LCALL HIT_MISS_COORD	;preenche no tabuleiro de ataque  
    JNB FHIT,CONTINUE_RND
        INC AUTOreg
    CONTINUE_RND:
	RET

FIND_DIR:
    MOV R4,#11001001B               ;limite de tentativas de procura de jogada valida
FINDING_DIR:
    MOV POSX,LPOSX
    MOV POSY,LPOSY 

    MOV A,R4                       ;limite de tentativas de procura de jogada valida
    CLR C
    RRC   A
    MOV R4,A
    JC FIND_ON_HORIZ
        MOV A,R4
       ; CLR C
        RRC   A
        MOV R4,A
        JC INC_POSY
            ANL AUTOREG,#0F3H   ;MODdir1=0 MODdir0=0
                                ;caso acertar o barco está dirigido para cima
            DEC POSY
            JMP CHECK_VLDV
        INC_POSY:
            ANL AUTOREG,#0F3H    ;caso acertar o barco está dirigido para baixo
            ORL AUTOREG,#04     ;MODdir1=0 MODdir0=1     
                           
            INC POSY
            ;JMP CHECK_VLDV
    CHECK_VLDV:
    MOV COD_ASCII,#0
    MOV A,POSY
    LCALL CHECK_COORD
    JB VALID_COORD,CHECK_VLD
    MOV A, R4
    JNZ FINDING_DIR
    JMP RND_VLDPLAY
    FIND_ON_HORIZ:
        MOV A,R4
        CLR C
        RRC   A
        MOV R4,A
        JC INC_POSX
            ANL AUTOREG,#0F3H    ;caso acertar o barco está dirigido para a esquerda
            ORL AUTOREG,#08H
                                    ;MODdir1=1 MODdir0=0   
            DEC POSX
            JMP CHECK_VLDH
        INC_POSX:
            ANL AUTOREG,#0F3H    ;caso acertar o barco está dirigido para a direita
            ORL AUTOREG,#0CH     ;MODdir1=1 MODdir0=1    
            INC POSX
            
    CHECK_VLDH:
    MOV COD_ASCII,#0
    MOV A,POSX
    LCALL CHECK_COORD
    JB VALID_COORD,CHECK_VLD
    MOV A, R4
    JNZ FINDING_DIR
    JMP RND_VLDPLAY
    CHECK_VLD:
    LCALL ALREADY_COORD		;verifica se já acertou nessa coordenada
	JNB	ALRCOORD,EXECUTE2find 	;caso não volta a esperar nova coordenada
    MOV A, R4
    JNZ FINDING_DIR
    JMP RND_VLDPLAY
EXECUTE2find:
    LCALL HIT_MISS_COORD	;preenche no tabuleiro de ataque  
    JNB FHIT,CONTINUE_FND
        MOV LPOSX,POSX
        MOV LPOSY,POSY
        INC AUTOreg
    CONTINUE_FND:
	RET

FIND_1LIMIT:
    MOV POSX,LPOSX
    MOV POSY,LPOSY 
    MOV A,AUTOREG
    ANL A,#0CH
    RR A
    RR A                ;passar a direção para os bits menos significativos do acumulador
    MOV DPTR,#CASEDIR
    RL A
    JMP @A+DPTR
    CASEDIR:
    AJMP DIR_UP
    AJMP DIR_DOWN
    AJMP DIR_LEFT
    ;AJMP DIR_RIGHT
    DIR_RIGHT:
        INC POSX
        JMP CHECK_HITVLDH
    DIR_UP:
        DEC POSY
        JMP CHECK_HITVLDV

    DIR_DOWN:
        INC POSY
    CHECK_HITVLDV:
    MOV COD_ASCII,#0
    MOV A,POSY
    LCALL CHECK_COORD
    JNB VALID_COORD,FIND_2LIMIT
    JMP CHECK_HITVLD

    DIR_LEFT:
        DEC POSX
    CHECK_HITVLDH:
    MOV COD_ASCII,#0
    MOV A,POSX
    LCALL CHECK_COORD
    JNB VALID_COORD,FIND_2LIMIT

    CHECK_HITVLD:
    LCALL ALREADY_COORD		;verifica se já acertou nessa coordenada
	JB	ALRCOORD,FIND_2LIMIT 	;caso sim volta a esperar nova coordenada
    LCALL HIT_MISS_COORD	;preenche no tabuleiro de ataque  
    JNB FHIT,FOUNDLIMIT
        MOV LPOSX,POSX
        MOV LPOSY,POSY
	RET
    FOUNDLIMIT:
        MOV LPOSX,IPOSX
        MOV LPOSY,IPOSY
        INC AUTOreg
	RET
FIND_2LIMIT:
    ORL AUTOREG,#03H
    MOV POSX,LPOSX
    MOV POSY,LPOSY 
    MOV A,AUTOREG
    ANL A,#0CH
    RR A
    RR A                ;passar a direção para os bits menos significativos do acumulador
    MOV DPTR,#CASEINVDIR
    RL A
    JMP @A+DPTR
    CASEINVDIR:
    AJMP INVDIR_UP
    AJMP INVDIR_DOWN
    AJMP INVDIR_LEFT
    ;AJMP DIR_RIGHT
    INVDIR_RIGHT:
        DEC POSX
        JMP CHECK_HITVLD2H
    INVDIR_UP:
        INC POSY
        JMP CHECK_HITVLD2V
    INVDIR_DOWN:
        DEC POSY
     CHECK_HITVLD2V:
    MOV COD_ASCII,#0
    MOV A,POSX
    LCALL CHECK_COORD
    JB VALID_COORD, CHECK_HITVLD2
    JMP RND_VLDPLAY
    INVDIR_LEFT:
        INC POSX
    CHECK_HITVLD2H:
    MOV COD_ASCII,#0
    MOV A,POSX
    LCALL CHECK_COORD
    JB VALID_COORD, CHECK_HITVLD2
    JMP RND_VLDPLAY
    CHECK_HITVLD2:
    LCALL ALREADY_COORD		;verifica se já acertou nessa coordenada
	JNB	ALRCOORD, EXECUTE_move2
    JMP RND_VLDPLAY	;caso sim volta a esperar nova coordenada
    EXECUTE_move2:
    LCALL HIT_MISS_COORD	;preenche no tabuleiro de ataque  
    JNB FHIT,SHIPDESTROYD
        MOV LPOSX,POSX
        MOV LPOSY,POSY
	RET
    SHIPDESTROYD:
        MOV LPOSX,IPOSX
        MOV LPOSY,IPOSY
        MOV AUTOREG,#0   ;volta a fazer jogada aleatoria
	RET
END    