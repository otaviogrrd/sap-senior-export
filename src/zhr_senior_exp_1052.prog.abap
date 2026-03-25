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
PARAMETERS: p_dir TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK blc1.
*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM zf_search_help_directory.

START-OF-SELECTION.

  IF p_dir IS INITIAL.
    MESSAGE 'Informe o diretorio local de destino.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*&---------------------------------------------------------------------*
*&      Form  ZF_SEARCH_HELP_DIRECTORY
*&---------------------------------------------------------------------*
FORM zf_search_help_directory.

  DATA lv_folder TYPE string.
  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF NOT lv_folder IS INITIAL.
    p_dir = lv_folder.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_NORMALIZAR_CAMINHOS
*&---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_dir ) - 1.

  IF p_dir IS NOT INITIAL.
    lv_last = p_dir+vl_strlen(1).
    IF lv_last <> '/' AND lv_last <> '\'.
      CONCATENATE p_dir '\' INTO p_dir.
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

  lv_filename = p_dir && sy-datum && '_SENIOR_1052.csv'.

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

  PERFORM f_salvar_arquivo USING lv_filename CHANGING lt_conv.

  WRITE: / 'Arquivo gerado com sucesso:', lv_filename.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                      CHANGING pt_file TYPE truxs_t_text_data.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = pv_filename
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
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
