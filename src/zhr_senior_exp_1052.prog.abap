REPORT zhr_senior_exp_1052.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         codesc TYPE c LENGTH 8,
         nomesc TYPE c LENGTH 30,
         tipesc TYPE c LENGTH 1,
         turesc TYPE n LENGTH 1,
         hordsr TYPE p DECIMALS 2,
         horsem TYPE p DECIMALS 2,
         pagepf TYPE c LENGTH 1,
         tipfer TYPE c LENGTH 1,
         tipjor TYPE n LENGTH 1,
         desjor TYPE c LENGTH 100,
         tipjos TYPE n LENGTH 2,
         dessim TYPE c LENGTH 999,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

*-Tela de Sele??o -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_locl  TYPE string LOWER CASE,
            p_serv TYPE sapb-sappfad DEFAULT '/usr/sap/tmp/'.
SELECTION-SCREEN END OF BLOCK blc1.
*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory.

START-OF-SELECTION.

  IF p_locl IS INITIAL AND p_serv IS INITIAL.
    MESSAGE 'Informe o destino local ou no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

FORM f_selecionar_arquivo.

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

FORM zf_search_help_directory.

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

FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_locl IS NOT INITIAL.
    vl_strlen = strlen( p_locl ) - 1.
    IF vl_strlen >= 0.
      lv_last = p_locl+vl_strlen(1).
      IF lv_last <> '/' AND lv_last <> '\'.
        CONCATENATE p_locl '\' INTO p_locl.
      ENDIF.
    ENDIF.
  ENDIF.

  vl_strlen = strlen( p_serv ) - 1.
  IF p_serv IS NOT INITIAL AND vl_strlen >= 0.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/' AND lv_last <> '\'.
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

  IF p_serv IS NOT INITIAL.
    lv_filename = p_serv && sy-datum && '_SENIOR_1052.csv'.
  ELSE.
    lv_filename = p_locl && sy-datum && '_SENIOR_1052.csv'.
  ENDIF.
  
  SELECT t508a~schkz,t508a~zmodn,t508a~wostd,
         t508s~rtext
    INTO TABLE @DATA(lt_dados)
    FROM t508a
    INNER JOIN t508s ON t508s~zeity EQ t508a~zeity
                    AND t508s~mofid EQ t508a~mofid
                    AND t508s~mosid EQ t508a~mosid
                    AND t508s~schkz EQ t508a~schkz
   WHERE t508a~mofid EQ 'BR'
     AND t508a~mosid EQ '37'
     AND t508s~sprsl EQ @sy-langu.

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

  IF p_serv IS NOT INITIAL.
    OPEN DATASET lv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE |Erro abrindo arquivo { lv_filename }| TYPE 'E'.
    ENDIF.

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
  ELSE.
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename = lv_filename
        filetype = 'ASC'
      TABLES
        data_tab = lt_conv
      EXCEPTIONS
        OTHERS   = 1.

    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
    ENDIF.

    WRITE: / 'Arquivo gerado com sucesso:', lv_filename.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESS_REGISTRATION
*&---------------------------------------------------------------------*
FORM zf_process_registration USING us_dados TYPE any.

  APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

  " C?digo da Escala
  ASSIGN COMPONENT 'SCHKZ' OF STRUCTURE us_dados TO FIELD-SYMBOL(<lf_value>).
  <lf_file>-codesc = <lf_value>.

  " Nome da Escala
  ASSIGN COMPONENT 'RTEXT' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-nomesc = <lf_value>.

  " Tipo da Escala
*<lf_file>-TIPESC

  " Turno da Escala
*  <lf_file>-turesc = .

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

  " Descri??o da Jornada eSocial
*<lf_file>-DESJOR

  " Tipo de jornada para o eSocial Simplificado
*<lf_file>-TIPJOS

  " Descri??o da Jornada eSocial Simplificado
*<lf_file>-DESSIM

ENDFORM.