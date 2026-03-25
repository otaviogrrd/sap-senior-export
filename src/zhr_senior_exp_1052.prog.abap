REPORT zhr_senior_exp_1052.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         codesc TYPE c LENGTH 8,
         nomesc TYPE c LENGTH 30,
         tipesc TYPE c LENGTH 1,
         turesc TYPE n LENGTH 1,
         hordsr TYPE t,
         horsem TYPE t,
         pagepf TYPE c LENGTH 1,
         tipfer TYPE c LENGTH 1,
         tipjor TYPE n LENGTH 1,
         desjor TYPE c LENGTH 100,
         tipjos TYPE n LENGTH 2,
         dessim TYPE c LENGTH 999,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

*-Tela de Seleção -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.
SELECTION-SCREEN END OF BLOCK blc1.
*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*&---------------------------------------------------------------------*
*&      Form  ZF_SEARCH_HELP_DIRECTORY
*&---------------------------------------------------------------------*
FORM zf_search_help_directory.

  DATA lv_serverfile TYPE string.
  CALL FUNCTION '/SAPDMC/LSM_F4_SERVER_FILE'
    IMPORTING
      serverfile       = lv_serverfile
    EXCEPTIONS
      canceled_by_user = 1
      OTHERS           = 2.

  IF NOT lv_serverfile IS INITIAL.
    p_serv = |{ lv_serverfile }/|.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_NORMALIZAR_CAMINHOS
*&---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_EXPORTAR_DADOS
*&---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA: lt_conv TYPE truxs_t_text_data.

  DATA: ls_data TYPE gy_file.

  DATA: lv_filename TYPE string,
        lv_header   TYPE string,
        lv_line     TYPE string.

  DATA: lv_erro TYPE flag.

  lv_filename = p_serv && sy-datum && '_SENIOR_1052.csv'.
  OPEN DATASET lv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
  IF sy-subrc <> 0.
    MESSAGE |Erro abrindo arquivo { lv_filename }| TYPE 'E'.
  ENDIF.

  SELECT pa0000~pernr,
         pa0001~persg,pa0001~persk,
         pa0007~schkz,pa0007~wostd
   INTO TABLE @DATA(lt_dados)
   FROM pa0000
   INNER JOIN pa0001 ON pa0001~pernr EQ pa0000~pernr
   INNER JOIN pa0007 ON pa0007~pernr EQ pa0000~pernr
  WHERE pa0000~endda EQ '99991231'
    AND pa0001~endda EQ '99991231'
    AND pa0007~endda EQ '99991231'.

  LOOP AT lt_dados ASSIGNING FIELD-SYMBOL(<lf_dados>).
    PERFORM zf_process_registration USING <lf_dados>.
  ENDLOOP.

  CALL FUNCTION 'SAP_CONVERT_TO_CSV_FORMAT'
    EXPORTING
      i_field_seperator    = ';'
    TABLES
      i_tab_sap_data       = gt_file
    CHANGING
      i_tab_converted_data = lt_conv
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  " Header
  DATA(lo_typedescr) = cl_abap_typedescr=>describe_by_data( ls_data ).
  IF lo_typedescr->kind = cl_abap_typedescr=>kind_struct.
    DATA(lo_structdescr) = CAST cl_abap_structdescr( lo_typedescr ).
    DATA(lt_components) = lo_structdescr->components.
    LOOP AT lt_components ASSIGNING FIELD-SYMBOL(<lf_component>).
      lv_header = |{ lv_header }| & |;|  & |{ <lf_component>-name }|.
    ENDLOOP.
    lv_header = lv_header+1.
  ENDIF.
  INSERT lv_header INTO lt_conv INDEX 1.

  LOOP AT lt_conv INTO DATA(ls_conv).
    TRANSFER ls_conv TO lv_filename.
    IF sy-subrc NE 0.
      lv_erro = abap_true. EXIT.
    ENDIF.
  ENDLOOP.
  CLOSE DATASET lv_filename.

  IF lv_erro IS NOT INITIAL.
    MESSAGE 'Erro ao gerar arquivo' TYPE 'E'.
  ELSE.
    WRITE: / 'Arquivo gerado com sucesso:', lv_filename.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESS_REGISTRATION
*&---------------------------------------------------------------------*
FORM zf_process_registration USING us_dados TYPE any.

  DATA: lv_persg  TYPE persg,
        lv_persk  TYPE persk,
        lv_schkz  TYPE schkn,
        lv_rtext  TYPE char100,
        lv_tipcol TYPE c LENGTH 1,
        lv_dats   TYPE d,
        lv_datopc TYPE char10.

  APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

  " Código da Escala
  ASSIGN COMPONENT 'SCHKZ' OF STRUCTURE us_dados TO FIELD-SYMBOL(<lf_value>).
  <lf_file>-codesc = <lf_value>.

  " Nome da Escala
  ASSIGN COMPONENT 'PERSG' OF STRUCTURE us_dados TO <lf_value>.
  lv_persg = <lf_value>.
  ASSIGN COMPONENT 'PERSK' OF STRUCTURE us_dados TO <lf_value>.
  lv_persk = <lf_value>.

  lv_schkz = <lf_file>-codesc.
  PERFORM zf_get_texto_schkz USING lv_persg lv_persk lv_schkz CHANGING lv_rtext.
  <lf_file>-nomesc = lv_rtext.

  " Tipo da Escala
*<lf_file>-TIPESC

  " Turno da Escala
*<lf_file>-TURESC

  " Horas de DSR
*<lf_file>-HORDSR

  " Horas na Semana
  ASSIGN COMPONENT 'WOSTD' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-horsem = <lf_value>.

  " Pagar extras proporcionais no feriado
*<lf_file>-PAGEPF

  " Tipo de Feriado da Escala
*<lf_file>-TIPFER

  " Tipo de jornada para o eSocial
*<lf_file>-TIPJOR

  " Descrição da Jornada eSocial
*<lf_file>-DESJOR

  " Tipo de jornada para o eSocial Simplificado
*<lf_file>-TIPJOS

  " Descrição da Jornada eSocial Simplificado
*<lf_file>-DESSIM

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_GET_TEXTO_SCHKZ
*&---------------------------------------------------------------------*
FORM zf_get_texto_schkz USING uv_persg TYPE persg
                              uv_persk TYPE persk
                              uv_schkz TYPE schkn
                     CHANGING cv_rtext TYPE char100.

  CLEAR cv_rtext.
  SELECT SINGLE persg,persk,zeity INTO @DATA(ls_t503)
     FROM t503
   WHERE persg EQ @uv_persg
     AND persk EQ @uv_persk.
  IF sy-subrc EQ 0.
    " Regra do plano de horário de trabalho
    SELECT zeity,mofid,mosid,schkz,endda,begda,zmodn,wostd INTO @DATA(ls_t508a) UP TO 1 ROWS
      FROM t508a
     WHERE zeity EQ @ls_t503-zeity
       AND mosid EQ @pbr99_molga
       ORDER BY endda DESCENDING.
    ENDSELECT.
    IF sy-subrc EQ 0.
      SELECT SINGLE schkz,rtext INTO @DATA(ls_t508s)
        FROM t508s
       WHERE zeity EQ @ls_t503-zeity
         AND mofid EQ @ls_t508a-mofid
         AND mosid EQ @ls_t508a-mosid
         AND schkz EQ @uv_schkz.
      IF sy-subrc EQ 0.
        cv_rtext = to_upper( ls_t508s-rtext ).
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
