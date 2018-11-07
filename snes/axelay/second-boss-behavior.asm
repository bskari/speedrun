; Second boss behavior assembly
; 15c7 stores the 2nd boss's current action:
; 3 - loading offscreen
; 7 - loading offscreen
; 8 - standing up, chained
; 9 - walking backward after being unchained
; #$0a/11 - step 1?
; #$0b/12 - step?
; #$0f/15 - laser
; #$12/18 - step 2?
; #$13/19 - machine gun
; #$15/21 - firing bullets
; #$16/22 - death 1
; #$17/23 - death 2
; #$18/24 - death 3
C1/EAF2:	A90C00  	LDA #$000C
C1/EAF5:	540001  	MVN $00,$01
C1/EAF8:	FA      	PLX 
C1/EAF9:	AB      	PLB 
C1/EAFA:	A90280  	LDA #$8002
C1/EAFD:	853E    	STA $3E
C1/EAFF:	A90300  	LDA #$0003
C1/EB02:	8DD200  	STA $00D2
C1/EB05:	B506    	LDA $06,X	; 15be ? changes a lot
C1/EB07:	C90080  	CMP #$8000
C1/EB0A:	B016    	BCS $EB22
C1/EB0C:	F60F    	INC $0F,X	; 15c7 action (chained)
C1/EB0E:	8012    	BRA $EB22
; ---
C1/EB10:	B514    	LDA $14,X
C1/EB12:	18      	CLC 
C1/EB13:	696000  	ADC #$0060
C1/EB16:	9514    	STA $14,X
C1/EB18:	2900FF  	AND #$FF00
C1/EB1B:	D005    	BNE $EB22	; branch if zero
C1/EB1D:	F60F    	INC $0F,X	; 15cy action (unchained)
C1/EB1F:	EE1A06  	INC $061A
C1/EB22:	A9C000  	LDA #$00C0
C1/EB25:	957C    	STA $7C,X	; 1634 health
C1/EB27:	A9FF00  	LDA #$00FF
C1/EB2A:	95AC    	STA $AC,X	; 1664 machine gun health
C1/EB2C:	E220    	SEP #$20
C1/EB2E:	B515    	LDA $15,X	; 15cd boss x
C1/EB30:	952B    	STA $2B,X	; 15e3 boss x?
C1/EB32:	38      	SEC 
C1/EB33:	E9C0    	SBC #$C0
C1/EB35:	49FF    	EOR #$FF
C1/EB37:	1A      	INC A
C1/EB38:	18      	CLC 
C1/EB39:	69C0    	ADC #$C0
C1/EB3B:	9543    	STA $43,X	; 15fb boss x?
C1/EB3D:	826002  	BRL $EDA0
C1/EB40:	AD1008  	LDA $0810	; 15fb boss x?
C1/EB43:	D01B    	BNE $EB60	; branch if zero
C1/EB45:	F60F    	INC $0F,X	; 15c7 state
C1/EB47:	E220    	SEP #$20
C1/EB49:	A918    	LDA #$18
C1/EB4B:	8D0007  	STA $0700
C1/EB4E:	8D1007  	STA $0710
C1/EB51:	A958    	LDA #$58
C1/EB53:	8D0307  	STA $0703
C1/EB56:	8D1307  	STA $0713
C1/EB59:	C220    	REP #$20
C1/EB5B:	A90280  	LDA #$8002
C1/EB5E:	853E    	STA $3E
C1/EB60:	A9C000  	LDA #$00C0
C1/EB63:	957C    	STA $7C,X	; 1634 health
C1/EB65:	A9FF00  	LDA #$00FF
C1/EB68:	95AC    	STA $AC,X	; 1664 machine gun health
C1/EB6A:	E220    	SEP #$20
C1/EB6C:	203BF2  	JSR $F23B
C1/EB6F:	C220    	REP #$20
C1/EB71:	A90060  	LDA #$6000
C1/EB74:	A00001  	LDY #$0100
C1/EB77:	820D01  	BRL $EC87
C1/EB7A:	E220    	SEP #$20
C1/EB7C:	A940    	LDA #$40
C1/EB7E:	9513    	STA $13,X	; 15cb frames until can do an action again
C1/EB80:	C220    	REP #$20
C1/EB82:	F60F    	INC $0F,X	; 15c7 action
C1/EB84:	E220    	SEP #$20
C1/EB86:	ADD600  	LDA $00D6	; frame counter
C1/EB89:	2903    	AND #$03
C1/EB8B:	D006    	BNE $EB93	; branch if zero
C1/EB8D:	B513    	LDA $13,X	; 14cb frames until can do an action again
C1/EB8F:	F002    	BEQ $EB93	; branch if zero
C1/EB91:	D613    	DEC $13,X	; 15cb frames until can do an action again
C1/EB93:	AD1606  	LDA $0616	; 2 = left foot moving, 1 = right foot moving, 3 = neither
C1/EB96:	1A      	INC A
C1/EB97:	2903    	AND #$03
C1/EB99:	D07A    	BNE $EC15	; branch if zero
C1/EB9B:	B513    	LDA $13,X	; 15cb frames until can do an action again
C1/EB9D:	C940    	CMP #$40
C1/EB9F:	B013    	BCS $EBB4	; branch if countdown >= 0x40/64
C1/EBA1:	A5D6    	LDA $D6		; frame counter I think?
C1/EBA3:	300F    	BMI $EBB4	; branch if minus
C1/EBA5:	C220    	REP #$20
C1/EBA7:	202FF2  	JSR $F22F
C1/EBAA:	E220    	SEP #$20
C1/EBAC:	9006    	BCC $EBB4
C1/EBAE:	A90C    	LDA #$0C
C1/EBB0:	950F    	STA $0F,X	; 15c7 action
C1/EBB2:	8061    	BRA $EC15
; ---
C1/EBB4:	B517    	LDA $17,X	; 15cf walk direction, 0 = forward, 1 = forward and have taken damage, 255 = backward
C1/EBB6:	100E    	BPL $EBC6
C1/EBB8:	B537    	LDA $37,X	; 15ef left knee? x
C1/EBBA:	D51F    	CMP $1F,X	; 15d7 left foot? x
C1/EBBC:	1002    	BPL $EBC0
C1/EBBE:	B51F    	LDA $1F,X	; 15d7 left foot? x
C1/EBC0:	C970    	CMP #$70
C1/EBC2:	B03A    	BCS $EBFE
C1/EBC4:	800F    	BRA $EBD5
; ---
C1/EBC6:	B537    	LDA $37,X	; 15ef left knee? x
C1/EBC8:	D51F    	CMP $1F,X	; 15d7 left foot? x
C1/EBCA:	3002    	BMI $EBCE
C1/EBCC:	B51F    	LDA $1F,X	; 15d7 left foot? x
C1/EBCE:	0A      	ASL A
C1/EBCF:	B02D    	BCS $EBFE
C1/EBD1:	C930    	CMP #$30
C1/EBD3:	9029    	BCC $EBFE
C1/EBD5:	B513    	LDA $13,X	; 15cb frames until we can do an action again
C1/EBD7:	D03C    	BNE $EC15	; branch if zero
C1/EBD9:	AD0710  	LDA $1007	; Axelay x
C1/EBDC:	38      	SEC
C1/EBDD:	F507    	SBC $07,X	; 15bf enemy x position
C1/EBDF:	1015    	BPL $EBF6	; branch if plus
C1/EBE1:	B597    	LDA $97,X	; 164f computed x position, used for laser
C1/EBE3:	3011    	BMI $EBF6	; branch if minus
C1/EBE5:	C910    	CMP #$10
C1/EBE7:	9015    	BCC $EBFE	; branch if laser position < 10
C1/EBE9:	B57C    	LDA $7C,X	; 1634 health
C1/EBEB:	C990    	CMP #$90
C1/EBED:	900B    	BCC $EBFA	; branch if health < 0x90/144
C1/EBEF:	ADD600  	LDA $00D6	; frame counter
C1/EBF2:	2915    	AND #$15
C1/EBF4:	F004    	BEQ $EBFA	; branch if zero
C1/EBF6:	A914    	LDA #$14	; bullets - 1
C1/EBF8:	8002    	BRA $EBFC
; ---
C1/EBFA:	A90E    	LDA #$0E	; laser - 1
C1/EBFC:	950F    	STA $0F,X	; 15c7 action (first step toward laser)
C1/EBFE:	C220    	REP #$20
C1/EC00:	B516    	LDA $16,X	; 15ce walk direction, 0xC0 = forward, 0x40 = backward
C1/EC02:	4D1C06  	EOR $061C
C1/EC05:	0A      	ASL A
C1/EC06:	9003    	BCC $EC0B
C1/EC08:	207FB2  	JSR $B27F
C1/EC0B:	B516    	LDA $16,X	; 15ce walk direction, C0 = forward, 0x40 = backward
C1/EC0D:	8D1C06  	STA $061C
C1/EC10:	A90060  	LDA #$6000
C1/EC13:	806F    	BRA $EC84
; ---
C1/EC15:	C220    	REP #$20
C1/EC17:	B57C    	LDA $7C,X	; 1634 health
C1/EC19:	2900F8  	AND #$F800
C1/EC1C:	D014    	BNE $EC32	; branch if zero
C1/EC1E:	B516    	LDA $16,X	; 15ce walk direction, C0 = forward, 40 = backward
C1/EC20:	18      	CLC 
C1/EC21:	7514    	ADC $14,X	; 15cc changes quickly when walking backward?
C1/EC23:	9514    	STA $14,X	; 15cc changes quickly when walking backward?
C1/EC25:	EB      	XBA 
C1/EC26:	E220    	SEP #$20
C1/EC28:	952B    	STA $2B,X	; 15e3 boss x?
C1/EC2A:	18      	CLC
C1/EC2B:	6980    	ADC #$80
C1/EC2D:	9543    	STA $43,X	; 15fb boss x?
C1/EC2F:	826E01  	BRL $EDA0
; ---
C1/EC32:	B516    	LDA $16,X	; 15ce walk direction, C0 = forward, 40 = backward
C1/EC34:	C900    	CMP #$00
C1/EC36:	806A    	BRA $ECA2
; ---
C1/EC38:	49FF    	EOR #$FF
C1/EC3A:	FF1A80E2	SBC $E2801A,X
C1/EC3E:	E220    	SEP #$20
C1/EC40:	A9C0    	LDA #$C0
C1/EC42:	9513    	STA $13,X	; 15cd brames until can do an action again
C1/EC44:	C220    	REP #$20
C1/EC46:	F60F    	INC $0F,X	; 15c7 action
C1/EC48:	8032    	BRA $EC7C
; ---
C1/EC4A:	E220    	SEP #$20
C1/EC4C:	D613    	DEC $13,X	; 15cb frames until can do an action gain
C1/EC4E:	F04D    	BEQ $EC9D	; branch if zero
C1/EC50:	C220    	REP #$20
C1/EC52:	202FF2  	JSR $F22F
C1/EC55:	B008    	BCS $EC5F
C1/EC57:	E220    	SEP #$20
C1/EC59:	A90A    	LDA #$0A
C1/EC5B:	950F    	STA $0F,X	; 15c7 action
C1/EC5D:	C220    	REP #$20
C1/EC5F:	AD0610  	LDA $1006	; Axelay micro x
C1/EC62:	0A      	ASL A
C1/EC63:	300E    	BMI $EC73	; branch if Axelay is on the right half of the screen
C1/EC65:	B5A8    	LDA $A8,X	; 1660 machine gun: 113 = alive, 0 = dead
C1/EC67:	D500    	CMP $00,X	; 15b8 boss type: 113 = T-36 Towbar
C1/EC69:	D008    	BNE $EC73
C1/EC6B:	E220    	SEP #$20
C1/EC6D:	A911    	LDA #$11	; 17 > laser anyway, so should bullet
C1/EC6F:	950F    	STA $0F,X	; 15c7 action
C1/EC71:	C220    	REP #$20
C1/EC73:	AD1606  	LDA $0616	; 2 = left foot moving, 1 = right foot moving, 3 = neither
C1/EC76:	1A      	INC A
C1/EC77:	290300  	AND #$0003
C1/EC7A:	D01B    	BNE $EC97	; branch if zero
C1/EC7C:	A00001  	LDY #$0100
C1/EC7F:	AD0610  	LDA $1006
C1/EC82:	8003    	BRA $EC87
; ---
C1/EC84:	A0C000  	LDY #$00C0
C1/EC87:	8490    	STY $90
C1/EC89:	38      	SEC 
C1/EC8A:	F506    	SBC $06,X	; 15be ? decrements slowly while walking, sometimes faster, stops when action
C1/EC8C:	0A      	ASL A
C1/EC8D:	A590    	LDA $90
C1/EC8F:	B004    	BCS $EC95
C1/EC91:	49FFFF  	EOR #$FFFF
C1/EC94:	1A      	INC A
C1/EC95:	9516    	STA $16,X	; 15ce walk direction, C0 = forward, 40 = backward
C1/EC97:	B516    	LDA $16,X	; 15ce walk direction
C1/EC99:	5C20EE03	JMP $03EE20
; ---
C1/EC9D:	A9FF95  	LDA #$95FF
C1/ECA0:	13C2    	ORA ($C2,S),Y	; I think this disassembly is wrong?
C1/ECA2:	201616  	JSR $1616
C1/ECA5:	80B8    	BRA $EC5F
; ---
C1/ECA7:	E220    	SEP #$20
C1/ECA9:	A91B    	LDA #$1B
C1/ECAB:	9527    	STA $27,X	; 15df 0x1A/26=normal? 0x1B/27=laser?
C1/ECAD:	953F    	STA $3F,X	; 157f ? never changes
C1/ECAF:	A91E    	LDA #$1E
C1/ECB1:	959F    	STA $9F,X	; 1657 0x1D/29=not firing, 0x1E/30=charging? 0x1F/31=aiming 0x20/32=laser 0x21/33=laster onscreen 0x22/34=laster
C1/ECB3:	A940    	LDA #$40
C1/ECB5:	95A3    	STA $A3,X	; 165b ? Only changes on death
C1/ECB7:	F60F    	INC $0F,X	; 15c7 action (This is where laser happens!)
C1/ECB9:	C220    	REP #$20
C1/ECBB:	82F700  	BRL $EDB5
; ---
C1/ECBE:	E220    	SEP #$20
C1/ECC0:	B59F    	LDA $9F,X	; 1657 laser status, 0x1D/29=not firing
C1/ECC2:	C91D    	CMP #$1D
C1/ECC4:	D006    	BNE $ECCC
C1/ECC6:	F60F    	INC $0F,X	; 15c7 action
C1/ECC8:	A920    	LDA #$20
C1/ECCA:	9513    	STA $13,X	; 15cb frames until can do an action again
C1/ECCC:	ADD600  	LDA $00D6	; frame counter
C1/ECCF:	2907    	AND #$07
C1/ECD1:	D008    	BNE $ECDB	; branch if zero
C1/ECD3:	B5A2    	LDA $A2,X
C1/ECD5:	18      	CLC 
C1/ECD6:	6940    	ADC #$40
C1/ECD8:	2053F2  	JSR $F253
C1/ECDB:	AD0C06  	LDA $060C
C1/ECDE:	C980    	CMP #$80
C1/ECE0:	6A      	ROR A
C1/ECE1:	C980    	CMP #$80
C1/ECE3:	6A      	ROR A
C1/ECE4:	C980    	CMP #$80
C1/ECE6:	6A      	ROR A
C1/ECE7:	18      	CLC 
C1/ECE8:	7515    	ADC $15,X
C1/ECEA:	952B    	STA $2B,X
C1/ECEC:	18      	CLC 
C1/ECED:	6980    	ADC #$80
C1/ECEF:	9543    	STA $43,X
C1/ECF1:	C220    	REP #$20
C1/ECF3:	82BF00  	BRL $EDB5
; ---
C1/ECF6:	E220    	SEP #$20
C1/ECF8:	D613    	DEC $13,X	; 15cb frames until can do an action again
C1/ECFA:	D0DF    	BNE $ECDB	; branch if zero
C1/ECFC:	A91A    	LDA #$1A
C1/ECFE:	9527    	STA $27,X	; 15df 27=laser? 26=normal?
C1/ED00:	953F    	STA $3F,X	; 15f7 something to do with laser?
C1/ED02:	A90A    	LDA #$0A	; walk
C1/ED04:	950F    	STA $0F,X	; 15c7 action
C1/ED06:	C220    	REP #$20
C1/ED08:	82AA00  	BRL $EDB5
; ---
C1/ED0B:	F60F    	INC $0F,X	; 15c7 action
C1/ED0D:	AD1606  	LDA $0616	; 2 = left foot moving, 1 = right foot moving, 3 = neighter
C1/ED10:	1A      	INC A
C1/ED11:	290300  	AND #$0003
C1/ED14:	F004    	BEQ $ED1A	; branch if zero
C1/ED16:	5C15EE03	JMP $03EE15
; ---
C1/ED1A:	B506    	LDA $06,X	; 15be ? changes a lot
C1/ED1C:	0A      	ASL A
C1/ED1D:	B021    	BCS $ED40
C1/ED1F:	101F    	BPL $ED40
C1/ED21:	202FF2  	JSR $F22F
C1/ED24:	E220    	SEP #$20
C1/ED26:	9011    	BCC $ED39
C1/ED28:	203BF2  	JSR $F23B
C1/ED2B:	B005    	BCS $ED32
C1/ED2D:	F60F    	INC $0F,X
C1/ED2F:	82A9FF  	BRL $ECDB
; ---
C1/ED32:	A914    	LDA #$14
C1/ED34:	950F    	STA $0F,X
C1/ED36:	82A2FF  	BRL $ECDB
; ---
C1/ED39:	A90A    	LDA #$0A	; step
C1/ED3B:	950F    	STA $0F,X	; 15c7 action
C1/ED3D:	829BFF  	BRL $ECDB
; ---
C1/ED40:	82BBFE  	BRL $EBFE
; ---
C1/ED43:	E220    	SEP #$20
C1/ED45:	B5A8    	LDA $A8,X	; 1660 machine gun: 0x71/113 = alive, 0=dead
C1/ED47:	D500    	CMP $00,X	; 15B8 boss type: 0x71/113 = boss
C1/ED49:	D0EE    	BNE $ED39
C1/ED4B:	B5B7    	LDA $B7,X	; 166f machine gun firing: 0x31/49 = no, 48/0x30 = between shots, 47/0x2f = yes
C1/ED4D:	C931    	CMP #$31
C1/ED4F:	D004    	BNE $ED55
C1/ED51:	5C39EF03	JMP $03EF39
; ---
C1/ED55:	ADD600  	LDA $00D6	; frame counter
C1/ED58:	2903    	AND #$03
C1/ED5A:	F004    	BEQ $ED60
C1/ED5C:	5CDBEE03	JMP $03EEDB
C1/ED60:	B5BA    	LDA $BA,X
C1/ED62:	3008    	BMI $ED6C
C1/ED64:	C940    	CMP #$40
C1/ED66:	900A    	BCC $ED72
C1/ED68:	A940    	LDA #$40
C1/ED6A:	8006    	BRA $ED72
; ---
C1/ED6C:	C9D0    	CMP #$D0
C1/ED6E:	B002    	BCS $ED72
C1/ED70:	A9D0    	LDA #$D0
C1/ED72:	2053F2  	JSR $F253
C1/ED75:	8263FF  	BRL $ECDB
; ---
C1/ED78:	E220    	SEP #$20
C1/ED7A:	A930    	LDA #$30
C1/ED7C:	9513    	STA $13,X	; 15cb frames until can do an action again
C1/ED7E:	C220    	REP #$20
C1/ED80:	F60F    	INC $0F,X	; 15c7 action
C1/ED82:	E220    	SEP #$20
C1/ED84:	D613    	DEC $13,X	; 15cb frames until can do an action again
C1/ED86:	D004    	BNE $ED8C	; branch if zero
C1/ED88:	A90A    	LDA #$0A
C1/ED8A:	950F    	STA $0F,X	; 15c7 action
C1/ED8C:	B513    	LDA $13,X	; 15cb frames until can do an action again
C1/ED8E:	291F    	AND #$1F
C1/ED90:	F004    	BEQ $ED96	; branch if zero
C1/ED92:	5CDBEE03	JMP $03EEDB
C1/ED96:	C220    	REP #$20
C1/ED98:	207FB2  	JSR $B27F
C1/ED9B:	E220    	SEP #$20
C1/ED9D:	823BFF  	BRL $ECDB
; ----
C1/EDA0:	E220    	SEP #$20
C1/EDA2:	B52C    	LDA $2C,X	; 15e4 target head angle?
C1/EDA4:	38      	SEC 
C1/EDA5:	F544    	SBC $44,X	; 15fc target head angle?
C1/EDA7:	C980    	CMP #$80
C1/EDA9:	6A      	ROR A
C1/EDAA:	18      	CLC 
C1/EDAB:	7544    	ADC $44,X	; 15fc target head angle?
C1/EDAD:	18      	CLC 
C1/EDAE:	6990    	ADC #$90
C1/EDB0:	2053F2  	JSR $F253
C1/EDB3:	C220    	REP #$20
C1/EDB5:	A00000  	LDY #$0000
C1/EDB8:	AD1606  	LDA $0616	; 2 = left foot moving, 1 = right foot moving, 3 = neighter
C1/EDBB:	290300  	AND #$0003
C1/EDBE:	F054    	BEQ $EE14	; branch if zero
C1/EDC0:	3A      	DEC A
C1/EDC1:	F017    	BEQ $EDDA	; branch if zero
C1/EDC3:	3A      	DEC A
C1/EDC4:	F01C    	BEQ $EDE2	; branch if zero
C1/EDC6:	E220    	SEP #$20
C1/EDC8:	B539    	LDA $39,X	; 15f1 right foot y
C1/EDCA:	38      	SEC 
C1/EDCB:	F547    	SBC $47,X	; 15ff right knee? y
C1/EDCD:	8590    	STA $90
C1/EDCF:	B521    	LDA $21,X	; 15d9 left foot y
C1/EDD1:	38      	SEC 
C1/EDD2:	F52F    	SBC $2F,X	; 15e7 left knee? y
C1/EDD4:	C590    	CMP $90
C1/EDD6:	C220    	REP #$20
C1/EDD8:	B008    	BCS $EDE2
C1/EDDA:	8A      	TXA 
C1/EDDB:	18      	CLC 
C1/EDDC:	691800  	ADC #$0018
C1/EDDF:	A8      	TAY 
C1/EDE0:	8006    	BRA $EDE8
; ---
C1/EDE2:	8A      	TXA 
C1/EDE3:	18      	CLC 
C1/EDE4:	693000  	ADC #$0030	; 15e8 I guess?
C1/EDE7:	A8      	TAY 
C1/EDE8:	B91500  	LDA $0015,Y	; 15fd?
C1/EDEB:	C90080  	CMP #$8000
C1/EDEE:	6A      	ROR A
C1/EDEF:	8590    	STA $90
C1/EDF1:	B90600  	LDA $0006,Y	; afa?
C1/EDF4:	38      	SEC 
C1/EDF5:	E590    	SBC $90
C1/EDF7:	9506    	STA $06,X	; 15be ? changes a lot
C1/EDF9:	E220    	SEP #$20
C1/EDFB:	B90900  	LDA $0009,Y	; afd?
C1/EDFE:	38      	SEC 
C1/EDFF:	F91700  	SBC $0017,Y	; b05?
C1/EE02:	9509    	STA $09,X	; 15c1 bullet launcher height
C1/EE04:	C220    	REP #$20
C1/EE06:	CC0A06  	CPY $060A	; 208 = right foot moving, 232 = right foot moving
C1/EE09:	F007    	BEQ $EE12
C1/EE0B:	A92100  	LDA #$0021
C1/EE0E:	220E9C00	JSR $009C0E
C1/EE12:	8011    	BRA $EE25
; ---
C1/EE14:	B50C    	LDA $0C,X	; 15c4 something to do with initial chain, set to 0 then increased to 224 and left alone
C1/EE16:	18      	CLC 
C1/EE17:	692000  	ADC #$0020
C1/EE1A:	C90002  	CMP #$0200
C1/EE1D:	B002    	BCS $EE21
C1/EE1F:	950C    	STA $0C,X	; 15c4 something to do with initial chain
C1/EE21:	2218AF02	JSR $02AF18
C1/EE25:	8C0A06  	STY $060A
C1/EE28:	9C1606  	STZ $0616	; 2 = left foot moving, 1 = right foot moving, 3 = neihter
C1/EE2B:	B57C    	LDA $7C,X	; 1634 health
C1/EE2D:	29FF00  	AND #$00FF
C1/EE30:	D01C    	BNE $EE4E	; branch if zero
C1/EE32:	E220    	SEP #$20
C1/EE34:	A916    	LDA #$16
C1/EE36:	950F    	STA $0F,X	; 15c7 action
C1/EE38:	C220    	REP #$20
C1/EE3A:	A9FFFF  	LDA #$FFFF
C1/EE3D:	8D2403  	STA $0324
C1/EE40:	A96000  	LDA #$0060
C1/EE43:	220E9C00	JSR $009C0E
C1/EE47:	A94700  	LDA #$0047
C1/EE4A:	220E9C00	JSR $009C0E
C1/EE4E:	B50F    	LDA $0F,X	; 15c7 action
C1/EE50:	29FF00  	AND #$00FF
C1/EE53:	C90A00  	CMP #$000A
C1/EE56:	904F    	BCC $EEA7	; branch if action < 11
C1/EE58:	B57D    	LDA $7D,X	; 1635 iframe counter, 0 = vulnerable
C1/EE5A:	29FF00  	AND #$00FF
C1/EE5D:	F02E    	BEQ $EE8D	; branch if zero
C1/EE5F:	4A      	LSR A
C1/EE60:	B020    	BCS $EE82
C1/EE62:	DA      	PHX 
C1/EE63:	8B      	PHB 
C1/EE64:	A2A9F1  	LDX #$F1A9
C1/EE67:	A0A222  	LDY #$22A2
C1/EE6A:	A90F00  	LDA #$000F
C1/EE6D:	547E01  	MVN $7E,$01
C1/EE70:	AB      	PLB 
C1/EE71:	FA      	PLX 
C1/EE72:	A9E03C  	LDA #$3CE0
C1/EE75:	8FCA227E	STA $7E22CA
C1/EE79:	A9E07D  	LDA #$7DE0
C1/EE7C:	8FCE227E	STA $7E22CE
C1/EE80:	8025    	BRA $EEA7
C1/EE82:	DA      	PHX 
C1/EE83:	A0A0F1  	LDY #$F1A0
C1/EE86:	222A8A00	JSR $008A2A
C1/EE8A:	FA      	PLX 
C1/EE8B:	801A    	BRA $EEA7
C1/EE8D:	E220    	SEP #$20
C1/EE8F:	AD1406  	LDA $0614	; frame counter since start of boss fight
C1/EE92:	C940    	CMP #$40
C1/EE94:	B00F    	BCS $EEA5	; branch if boss frame counter > 0x40
C1/EE96:	0A      	ASL A
C1/EE97:	0A      	ASL A
C1/EE98:	1002    	BPL $EE9C
C1/EE9A:	49FF    	EOR #$FF
C1/EE9C:	C220    	REP #$20
C1/EE9E:	A0C1F1  	LDY #$F1C1
C1/EEA1:	2233E203	JSR $03E233
C1/EEA5:	C220    	REP #$20
C1/EEA7:	A0C79E  	LDY #$9EC7
C1/EEAA:	2243B102	JSR $02B143
C1/EEAE:	ADD500  	LDA $00D5	; always 0?!?
C1/EEB1:	1004    	BPL $EEB7	; branch if signed value >= A
C1/EEB3:	49FFFF  	EOR #$FFFF
C1/EEB6:	1A      	INC A
C1/EEB7:	4A      	LSR A
C1/EEB8:	4A      	LSR A
C1/EEB9:	4A      	LSR A
C1/EEBA:	EB      	XBA 
C1/EEBB:	291F00  	AND #$001F
C1/EEBE:	8FDE237E	STA $7E23DE
C1/EEC2:	B506    	LDA $06,X	; 15be ? changes a lot
C1/EEC4:	38      	SEC 
C1/EEC5:	E9000B  	SBC #$0B00
C1/EEC8:	957E    	STA $7E,X	; 1636 ? seems to increase when forward, decrease backward, more quickly when about to step, ???
C1/EECA:	B508    	LDA $08,X	; 15c0 seems to change when walks off left screen
C1/EECC:	38      	SEC 
C1/EECD:	E90005  	SBC #$0500
C1/EED0:	9580    	STA $80,X	; 1638 ? changes sometimes after stepping toward left
C1/EED2:	2023F9  	JSR $F923
C1/EED5:	AD1406  	LDA $0614	; frame counter since start of boss fight
C1/EED8:	1A      	INC A
C1/EED9:	F003    	BEQ $EEDE	; branch if zero
C1/EEDB:	8D1406  	STA $0614
C1/EEDE:	5C81BE02	JMP $02BE81
; ---
C1/EEE2:	2215BC02	JSR $02BC15
C1/EEE6:	290400  	AND #$0004
C1/EEE9:	A8      	TAY 
C1/EEEA:	B9B9F1  	LDA $F1B9,Y
C1/EEED:	8FBE237E	STA $7E23BE
C1/EEF1:	B9BBF1  	LDA $F1BB,Y
C1/EEF4:	8FFE237E	STA $7E23FE
C1/EEF8:	B508    	LDA $08,X	; 1660 machine gun: 113=alive, 0=dead
C1/EEFA:	18      	CLC
C1/EEFB:	692900  	ADC #$0029
C1/EEFE:	9508    	STA $08,X	; 1660 machine gun: 113=alive, 0=dead
C1/EF00:	C900B0  	CMP #$B000
C1/EF03:	B011    	BCS $EF16
C1/EF05:	C900A0  	CMP #$A000
C1/EF08:	B046    	BCS $EF50
C1/EF0A:	A5D6    	LDA $D6
C1/EF0C:	290700  	AND #$0007
C1/EF0F:	F003    	BEQ $EF14
C1/EF11:	209FD6  	JSR $D69F
C1/EF14:	803A    	BRA $EF50
; ---
C1/EF16:	F60F    	INC $0F,X	; 15c7 action
C1/EF18:	9C0007  	STZ $0700
C1/EF1B:	9C1007  	STZ $0710
C1/EF1E:	9C1806  	STZ $0618
C1/EF21:	A90101  	LDA #$0101
C1/EF24:	8D1E06  	STA $061E
C1/EF27:	9C3009  	STZ $0930
C1/EF2A:	A91080  	LDA #$8010
C1/EF2D:	8D3E00  	STA $003E
C1/EF30:	2062B2  	JSR $B262
C1/EF33:	A96000  	LDA #$0060
C1/EF36:	220E9C00	JSR $009C0E
C1/EF3A:	E220    	SEP #$20
C1/EF3C:	A980    	LDA #$80
C1/EF3E:	9513    	STA $13,X
C1/EF40:	C220    	REP #$20
C1/EF42:	DA      	PHX 
C1/EF43:	A23016  	LDX #$1630
C1/EF46:	A90500  	LDA #$0005
C1/EF49:	A0E1F1  	LDY #$F1E1
C1/EF4C:	2098DC  	JSR $DC98
C1/EF4F:	FA      	PLX 
C1/EF50:	A5D6    	LDA $D6
C1/EF52:	820AFF  	BRL $EE5F
C1/EF55:	209FD6  	JSR $D69F
C1/EF58:	8B      	PHB 
C1/EF59:	DA      	PHX 
C1/EF5A:	AE1806  	LDX $0618
C1/EF5D:	AD1E06  	LDA $061E
C1/EF60:	8592    	STA $92
C1/EF62:	A9007F  	LDA #$7F00
C1/EF65:	48      	PHA 
C1/EF66:	AB      	PLB 
C1/EF67:	AB      	PLB 
C1/EF68:	A90001  	LDA #$0100
C1/EF6B:	8590    	STA $90
C1/EF6D:	BD00C0  	LDA $C000,X
C1/EF70:	E220    	SEP #$20
C1/EF72:	4A      	LSR A
C1/EF73:	9003    	BCC $EF78
C1/EF75:	9E00C0  	STZ $C000,X
C1/EF78:	EB      	XBA 
C1/EF79:	4A      	LSR A
C1/EF7A:	9003    	BCC $EF7F
C1/EF7C:	9E01C0  	STZ $C001,X
C1/EF7F:	C220    	REP #$20
C1/EF81:	E8      	INX 
C1/EF82:	E8      	INX 
C1/EF83:	C690    	DEC $90
C1/EF85:	D0E6    	BNE $EF6D
C1/EF87:	A2A022  	LDX #$22A0
C1/EF8A:	A90000  	LDA #$0000
C1/EF8D:	9F00007E	STA $7E0000,X
C1/EF91:	A95F00  	LDA #$005F
C1/EF94:	9B      	TXY 
C1/EF95:	C8      	INY 
C1/EF96:	547E7E  	MVN $7E,$7E
C1/EF99:	FA      	PLX 
C1/EF9A:	AB      	PLB 
C1/EF9B:	202EF9  	JSR $F92E
C1/EF9E:	9005    	BCC $EFA5
C1/EFA0:	9C1806  	STZ $0618
C1/EFA3:	8007    	BRA $EFAC
C1/EFA5:	18      	CLC 
C1/EFA6:	6D1806  	ADC $0618
C1/EFA9:	8D1806  	STA $0618
C1/EFAC:	A98000  	LDA #$0080
C1/EFAF:	38      	SEC 
C1/EFB0:	F513    	SBC $13,X
C1/EFB2:	2262B904	JSR $04B962
C1/EFB6:	E220    	SEP #$20
C1/EFB8:	B513    	LDA $13,X
C1/EFBA:	4A      	LSR A
C1/EFBB:	C904    	CMP #$04
C1/EFBD:	B003    	BCS $EFC2
C1/EFBF:	8D0D06  	STA $060D
C1/EFC2:	D613    	DEC $13,X
C1/EFC4:	C220    	REP #$20
C1/EFC6:	D061    	BNE $F029
C1/EFC8:	9C0007  	STZ $0700
C1/EFCB:	9C1007  	STZ $0710
C1/EFCE:	A90280  	LDA #$8002
C1/EFD1:	853E    	STA $3E
C1/EFD3:	22C1B900	JSR $00B9C1
C1/EFD7:	DA      	PHX 
C1/EFD8:	A90030  	LDA #$3000
C1/EFDB:	221FB902	JSR $02B91F
C1/EFDF:	FA      	PLX 
C1/EFE0:	F60F    	INC $0F,X
C1/EFE2:	E220    	SEP #$20
C1/EFE4:	A97C    	LDA #$7C
C1/EFE6:	9513    	STA $13,X
C1/EFE8:	C220    	REP #$20
C1/EFEA:	E220    	SEP #$20
C1/EFEC:	B513    	LDA $13,X
C1/EFEE:	F002    	BEQ $EFF2
C1/EFF0:	D613    	DEC $13,X
C1/EFF2:	4A      	LSR A
C1/EFF3:	4A      	LSR A
C1/EFF4:	09E0    	ORA #$E0
C1/EFF6:	8D3221  	STA $2132
C1/EFF9:	9C3021  	STZ $2130
C1/EFFC:	C220    	REP #$20
C1/EFFE:	A5D6    	LDA $D6
C1/F000:	290300  	AND #$0003
C1/F003:	D024    	BNE $F029
C1/F005:	9B      	TXY 
C1/F006:	22ADAE02	JSR $02AEAD
C1/F00A:	B01C    	BCS $F028
C1/F00C:	20E9DC  	JSR $DCE9
C1/F00F:	2215BC02	JSR $02BC15
C1/F013:	4A      	LSR A
C1/F014:	9506    	STA $06,X
C1/F016:	290F00  	AND #$000F
C1/F019:	8590    	STA $90
C1/F01B:	A90010  	LDA #$1000
C1/F01E:	9003    	BCC $F023
C1/F020:	A900C0  	LDA #$C000
C1/F023:	18      	CLC 
C1/F024:	658F    	ADC $8F
C1/F026:	9508    	STA $08,X
C1/F028:	BB      	TYX 
C1/F029:	2023F9  	JSR $F923
C1/F02C:	82AFFE  	BRL $EEDE
; ---
C1/F02F:	AD0810  	LDA $1008
C1/F032:	38      	SEC 
C1/F033:	F508    	SBC $08,X
C1/F035:	B003    	BCS $F03A
C1/F037:	C900E0  	CMP #$E000
C1/F03A:	60      	RTS 
; ---
C1/F03B:	B5A8    	LDA $A8,X	; 1660 machine gun: 113=alive, 0=dead
C1/F03D:	D500    	CMP $00,X	; 15b8 boss type: 113=T-36 Towbar
C1/F03F:	D010    	BNE $F051
C1/F041:	B5B7    	LDA $B7,X	; 166f machine gun firing: 0x31/49 = no, 48/0x30 = between shots, 47/0x2f = yes
C1/F043:	C931F0  	CMP #$F031	; not firing
C1/F046:	0A      	ASL A
C1/F047:	C92ED0  	CMP #$D02E	; ? machine gun status
C1/F04A:	06A9    	ASL $A9		; I think this disassembly is wrong...
C1/F04C:	2F95B718	AND $18B795
C1/F050:	60      	RTS 
