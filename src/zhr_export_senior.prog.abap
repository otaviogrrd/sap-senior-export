REPORT zhr_export_senior.


FORM f_selecionar_arquivo CHANGING p_locl.

  DATA lv_folder TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_folder IS NOT INITIAL.
    p_locl = lv_folder.
  ENDIF.

ENDFORM.

FORM zf_search_help_directory CHANGING p_serv.

  DATA lv_serverfile TYPE string.

  CALL FUNCTION '/SAPDMC/LSM_F4_SERVER_FILE'
    IMPORTING
      serverfile       = lv_serverfile
    EXCEPTIONS
      canceled_by_user = 1
      OTHERS           = 2.

  IF NOT lv_serverfile IS INITIAL.
    p_serv = lv_serverfile.
  ENDIF.

ENDFORM.

************************************************************************
* Convers??o TIPCOL (LTipCol)
************************************************************************
FORM f_conv_tipcol
  USING    p_persg
  CHANGING p_tipcol.

  CLEAR p_tipcol.

  CASE p_persg.

    WHEN '1'. " CLT
      p_tipcol = '1'.

    WHEN '4'. " Aprendiz
      p_tipcol = '1'.

    WHEN '5'. " Estagi??rio
      p_tipcol = '1'.

    WHEN '6'. " Prestador
      p_tipcol = '2'.

    WHEN '7'. " Pr??-labore
      p_tipcol = '3'.

    WHEN OTHERS.
      p_tipcol = '1'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Sexo (LTipSex)
************************************************************************
FORM f_conv_tipsex
  USING    p_gesch
  CHANGING p_sex.

  CLEAR p_sex.

  CASE p_gesch.

    WHEN '1' OR 'M'.
      p_sex = 'M'.

    WHEN '2' OR 'F'.
      p_sex = 'F'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Estado Civil (LEstCiv)
************************************************************************
FORM f_conv_estciv
  USING    p_famst
  CHANGING p_estciv.

  CLEAR p_estciv.

  CASE p_famst.

    WHEN '1'. p_estciv = '1'.
    WHEN '2'. p_estciv = '2'.
    WHEN '3'. p_estciv = '3'.
    WHEN '4'. p_estciv = '4'.
    WHEN '5'. p_estciv = '5'.
    WHEN '6'. p_estciv = '6'.
    WHEN '7'. p_estciv = '7'.

    WHEN OTHERS.
      p_estciv = '9'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Ra??a/Cor (LRacCor)
************************************************************************
FORM f_conv_raccor
  USING    p_race
  CHANGING p_raccor.

  CLEAR p_raccor.

  CASE p_race.

    WHEN '1'. p_raccor = '1'.
    WHEN '2'. p_raccor = '2'.
    WHEN '3'. p_raccor = '3'.
    WHEN '4'. p_raccor = '4'.
    WHEN '5'. p_raccor = '5'.

    WHEN OTHERS.
      p_raccor = '0'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Sim/N??o (LSimNao)
************************************************************************
FORM f_conv_simnao
  USING    p_flag
  CHANGING p_sn.

  CLEAR p_sn.

  CASE p_flag.

    WHEN 'X' OR '1' OR 'S'.
      p_sn = 'S'.

    WHEN OTHERS.
      p_sn = 'N'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Pagamento Sindicato (LPagSin)
************************************************************************
FORM f_conv_pagsin
  USING    p_val
  CHANGING p_pagsin.

  CLEAR p_pagsin.

  CASE p_val.

    WHEN 'S'. p_pagsin = 'S'.
    WHEN 'N'. p_pagsin = 'N'.
    WHEN 'M'. p_pagsin = 'M'.
    WHEN 'P'. p_pagsin = 'P'.

    WHEN OTHERS.
      p_pagsin = 'S'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Modo Pagamento (LModPag)
************************************************************************
FORM f_conv_modpag
  USING    p_zlsch
  CHANGING p_modpag.

  CLEAR p_modpag.

  CASE p_zlsch.

    WHEN 'C'. p_modpag = 'C'.
    WHEN 'D'. p_modpag = 'D'.
    WHEN 'O'. p_modpag = 'O'.
    WHEN 'R'. p_modpag = 'R'.
    WHEN 'E'. p_modpag = 'E'.
    WHEN 'P'. p_modpag = 'P'.

    WHEN OTHERS.
      p_modpag = 'D'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Tipo Aposentadoria (LTipApo)
************************************************************************
FORM f_conv_tipapo
  USING    p_tipo
  CHANGING p_tipapo.

  CLEAR p_tipapo.

  CASE p_tipo.

    WHEN '1'. p_tipapo = '1'.
    WHEN '2'. p_tipapo = '2'.
    WHEN '3'. p_tipapo = '3'.
    WHEN '4'. p_tipapo = '4'.
    WHEN '5'. p_tipapo = '5'.
    WHEN '6'. p_tipapo = '6'.
    WHEN '7'. p_tipapo = '7'.
    WHEN '8'. p_tipapo = '8'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Tipo Conta Banc??ria (LTpCtBa)
************************************************************************
FORM f_conv_tipctba
  USING    p_type
  CHANGING p_ctba.

  CLEAR p_ctba.

  CASE p_type.

    WHEN '1'. p_ctba = '1'.
    WHEN '2'. p_ctba = '2'.
    WHEN '3'. p_ctba = '3'.

    WHEN OTHERS.
      p_ctba = '9'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Per??odo Pagamento (LPerPag)
************************************************************************
FORM f_conv_perpag
  USING    p_per
  CHANGING p_perpag.

  CLEAR p_perpag.

  CASE p_per.

    WHEN 'M'. p_perpag = 'M'.
    WHEN 'S'. p_perpag = 'S'.
    WHEN 'Q'. p_perpag = 'Q'.

    WHEN OTHERS.
      p_perpag = 'M'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Tipo Chave Pix (LTipChv)
************************************************************************
FORM f_conv_tipchv
  USING    p_tipo
  CHANGING p_tipchv.

  CLEAR p_tipchv.

  CASE p_tipo.

    WHEN '1'. p_tipchv = '1'.
    WHEN '2'. p_tipchv = '2'.
    WHEN '3'. p_tipchv = '3'.
    WHEN '4'. p_tipchv = '4'.
    WHEN '5'. p_tipchv = '5'.

  ENDCASE.

ENDFORM.

************************************************************************
* Convers??o Estado (LEstFed)
************************************************************************

FORM f_conv_estfed
  USING    p_region
  CHANGING p_estado.

  CLEAR p_estado.

  IF p_region IS INITIAL.
    p_estado = ''.
    RETURN.
  ENDIF.

  TRANSLATE p_region TO UPPER CASE.
  p_estado = p_region.

ENDFORM.

FORM f_conv_tipcon
  USING    p_empid
  CHANGING p_tipcon.

  CLEAR p_tipcon.

  CASE p_empid.

    WHEN '01'. " Funcion??rio
      p_tipcon = '1'.  " Empregado

    WHEN '02'. " Trabalhador Rural
      p_tipcon = '3'.  " Trabalhador Rural

    WHEN '03'. " Estatut??rio
      p_tipcon = '9'.  " Agente P??blico

    WHEN '04'. " Estagi??rio
      p_tipcon = '5'.  " Estagi??rio

    WHEN '05'. " Diretor
      p_tipcon = '2'.  " Diretor

    WHEN '06'. " Conselheiro
      p_tipcon = '2'.  " Diretor

    WHEN '07'. " Tempor??rio
      p_tipcon = '7'.  " Prazo Determinado

    WHEN '08'. " Aut??nomo
      p_tipcon = '11'. " Cooperado

    WHEN '09'. " Pensionista
      p_tipcon = '4'.  " Aposentado

    WHEN '10'. " Comissionado
      p_tipcon = '1'.  " Empregado

    WHEN '11'. " Terceiro
      p_tipcon = '11'. " Cooperado

    WHEN '12'. " Menor aprendiz
      p_tipcon = '6'.  " Aprendiz

    WHEN OTHERS.
      p_tipcon = '1'.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_CONV_DATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_<FS_0041>_DAT01  text
*      <--P_LV_DATADM  text
*----------------------------------------------------------------------*
FORM f_conv_date  USING    p_date
                  CHANGING c_date.

  CHECK p_date IS NOT INITIAL.
  c_date = |{ p_date+6(2) }/{ p_date+4(2) }/{ p_date(4) }|.

ENDFORM.

FORM f_remove_mask
  USING    p_value
  CHANGING p_clean.

  p_clean = p_value.

  REPLACE ALL OCCURRENCES OF '.' IN p_clean WITH ''.
  REPLACE ALL OCCURRENCES OF '/' IN p_clean WITH ''.
  REPLACE ALL OCCURRENCES OF '-' IN p_clean WITH ''.
  REPLACE ALL OCCURRENCES OF ' ' IN p_clean WITH ''.

ENDFORM.


FORM f_conv_mes
  USING    p_mes
  CHANGING p_mes_out.

  CLEAR p_mes_out.

  IF p_mes IS INITIAL.
    p_mes_out = '01'.
  ELSE.
    p_mes_out = p_mes.
  ENDIF.

  " Garantir 2 posi????es
  IF strlen( p_mes_out ) = 1.
    p_mes_out = |0{ p_mes_out }|.
  ENDIF.

ENDFORM.

FORM f_conv_tpomvt
  USING    p_massn
  CHANGING p_tpomvt.

  CLEAR p_tpomvt.

  CASE p_massn.

    WHEN '1'. p_tpomvt = '1'. " Admiss??o
    WHEN '2'. p_tpomvt = '2'. " Demiss??o
    WHEN '3'. p_tpomvt = '3'. " Transfer??ncia
    WHEN '4'. p_tpomvt = '4'. " Promo????o

    WHEN OTHERS.
      p_tpomvt = '0'. " Default

  ENDCASE.

ENDFORM.

FORM f_conv_mtvalt
  USING    p_massg
  CHANGING p_mtvalt.

  CLEAR p_mtvalt.

  CASE p_massg.

    WHEN '04' OR '05'.
      p_mtvalt = '1'. " Altera????o cargo

    WHEN '06'.
      p_mtvalt = '2'. " Altera????o fun????o

    WHEN OTHERS.
      p_mtvalt = '0'. " Default obrigat??rio

  ENDCASE.

ENDFORM.

FORM f_conv_tipmot
  USING    p_massg
  CHANGING p_tipmot.

  CLEAR p_tipmot.

  CASE p_massg.

    WHEN '01' OR '02' OR '03'.
      p_tipmot = 'A'. " Admiss??o

    WHEN '04' OR '05' OR '06'.
      p_tipmot = 'M'. " Movimenta????o

    WHEN '07' OR '08'.
      p_tipmot = 'D'. " Desligamento

    WHEN OTHERS.
      p_tipmot = 'E'. " Default conforme regra

  ENDCASE.

ENDFORM.

FORM f_conv_admeso
  USING    p_massn
           p_massg
  CHANGING p_admeso.

  CLEAR p_admeso.

  IF p_massn = 'Z1'.
    CASE p_massg.

      WHEN '02'. " Emprego Adquirido
        p_admeso = '4'. " Transfer??ncia por motivo de sucess??o, incorpora????o, cis??o ou fus??o

      WHEN '03'. " Nova Contrata????o
        p_admeso = '1'. " Admiss??o

      WHEN '07'. " Contrato por prazo determinado
        p_admeso = '1'. " Admiss??o

      WHEN '08'. " Primeiro empregado
        p_admeso = '1'. " Admiss??o

      WHEN '10'. " Nova Contrata????o (Ev.2190)
        p_admeso = '1'. " Admiss??o

      WHEN '11'. " Reemprego (Recontrata????o)
        p_admeso = '1'. " Admiss??o

      WHEN OTHERS.
        p_admeso = '1'.

    ENDCASE.
  ENDIF.

ENDFORM.

FORM f_conv_indadm
  USING    p_massn
           p_massg
  CHANGING p_indadm.

  CLEAR p_indadm.

  p_indadm = '1'. " padr??o = Normal

  IF p_massn = 'ZA'
 AND p_massg = '01'.
    p_indadm = '3'. " Decorrente de Decis??o Judicial
  ENDIF.

ENDFORM.

FORM f_conv_tipadm
  USING    p_massn
           p_massg
  CHANGING p_tipadm.

  CLEAR p_tipadm.

  p_tipadm = '1'. " padr??o

  IF p_massn = 'Z1'.

    CASE p_massg.

      WHEN '01'. " Transf Internacional-Contrata????o
        p_tipadm = '5'.  " Incorpora????o/Fus??o/Cis??o/Outros

      WHEN '02'. " Emprego Adquirido
        p_tipadm = '5'.  " Incorpora????o/Fus??o/Cis??o/Outros

      WHEN '03'. " Nova Contrata????o
        p_tipadm = '1'.  " Primeiro Emprego

      WHEN '04'. " Transfer??ncia Protegida (c/TUP)
        p_tipadm = '3'.  " Transfer??ncia c/ ??nus

      WHEN '05'. " Reintegra????o
        p_tipadm = '6'.  " Reintegra????o

      WHEN '06'. " Headcount Or??ado
        p_tipadm = '1'.  " Primeiro Emprego

      WHEN '07'. " Contrato por prazo determinado
        p_tipadm = '1'.  " Primeiro Emprego

      WHEN '08'. " Primeiro empregado
        p_tipadm = '1'.  " Primeiro Emprego

      WHEN '09'. " Substitui????o
        p_tipadm = '1'.  " Primeiro Emprego

      WHEN '10'. " Nova Contrata????o (Ev.2190)
        p_tipadm = '1'.  " Primeiro Emprego

      WHEN '11'. " Reemprego (Recontrata????o)
        p_tipadm = '2'.  " Reemprego

      WHEN OTHERS.
        p_tipadm = '1'.

    ENDCASE.

  ENDIF.

ENDFORM.

FORM f_remove_special
  USING    p_value
  CHANGING p_result.

  DATA lv_value TYPE string.

  lv_value = p_value.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9A-Za-z]' IN lv_value WITH ''.
  p_result = lv_value.

ENDFORM.

FORM f_split_phone
  USING    p_phone
  CHANGING p_ddi
           p_ddd
           p_num.

  DATA lv_phone TYPE string.
  DATA lv_len   TYPE i.

  CLEAR: p_ddi, p_ddd, p_num.

  lv_phone = p_phone.

  REPLACE ALL OCCURRENCES OF '(' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF ')' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '-' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF ' ' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '/' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '.' IN lv_phone WITH ''.
  CONDENSE lv_phone NO-GAPS.

  lv_len = strlen( lv_phone ).

  IF lv_len >= 10.
    p_ddd = lv_phone+0(2).
    p_num = lv_phone+2.
  ELSEIF lv_len > 2.
    p_ddd = lv_phone+0(2).
    p_num = lv_phone+2.
  ELSE.
    p_num = lv_phone.
  ENDIF.

ENDFORM.
FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE
                              p_locl TYPE string
                              p_serv TYPE string.
  DATA:
    lv_folder   TYPE string,
    lv_server   TYPE string,
    lv_fullpath TYPE string,
    lv_line     TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.
  lv_server = p_serv.
  IF lv_server IS NOT INITIAL.
    lv_len = strlen( lv_server ) - 1.
    IF lv_len >= 0.
      lv_last = lv_server+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_server '/' INTO lv_server.
      ENDIF.
    ENDIF.
    CONCATENATE lv_server pv_filename INTO lv_fullpath.
    OPEN DATASET lv_fullpath FOR OUTPUT
      IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo no servidor.' TYPE 'E'.
    ENDIF.
    LOOP AT pt_file INTO lv_line.
      TRANSFER lv_line TO lv_fullpath.
    ENDLOOP.
    CLOSE DATASET lv_fullpath.
    p_serv = lv_server.
    RETURN.
  ENDIF.
  lv_folder = p_locl.
  IF lv_folder IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>directory_browse
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.
    IF sy-subrc <> 0 OR lv_folder IS INITIAL.
      MESSAGE 'Selecao de diretorio cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.
  lv_len = strlen( lv_folder ) - 1.
  IF lv_len >= 0.
    lv_last = lv_folder+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE lv_folder '\' INTO lv_folder.
    ENDIF.
  ENDIF.
  CONCATENATE lv_folder pv_filename INTO lv_fullpath.
  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.
  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.
  p_locl = lv_folder.
ENDFORM.
